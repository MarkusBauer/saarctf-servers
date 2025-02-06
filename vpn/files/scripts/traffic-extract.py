#!/opt/gameserver/run.sh
import argparse
import glob
import os
import re
import subprocess
import sys

DEFAULT_OUTPUT: str = '/tmp'
if os.path.exists('/tmp/extractedtraffic'):
    DEFAULT_OUTPUT = '/tmp/extractedtraffic'
TEAM_TRAFFIC_DIR: str = '/tmp/teamtraffic'

sys.path.append('/opt/gameserver/')
sys.path.append('../../../saarctf/')


def get_team_ranges(team_id: int) -> list[str]:
    import saarctf_commons.config
    range1 = saarctf_commons.config.team_id_to_network_range(team_id)
    range2 = saarctf_commons.config.team_id_to_vpn_peers(team_id)[0] + '/24'
    return [range1, range2]


def get_tshark_cmd(input: str, output: str, filter: str):
    return ['tshark', '-r', input, '-w', output, '-2', '-R', filter]


def get_latest_pcap(service_id: int) -> str | None:
    list_of_files = glob.glob(TEAM_TRAFFIC_DIR + f'/*_svc{service_id:02d}.pcap')
    if not list_of_files:
        return None
    return max(list_of_files, key=os.path.getctime)


def main() -> None:
    parser = argparse.ArgumentParser(description='Extract teams / service traffic from pcaps')
    parser.add_argument('pcaps', metavar='N', type=str, nargs='+',
                        help='pcap files, or a service number to pick the latest file')
    parser.add_argument('--port', '-p', type=int, action='append', default=[], help='filter for specific ports')
    parser.add_argument('--ip', '-i', type=str, action='append', default=[], help='filter for specific IP/subnet')
    parser.add_argument('--team', '-t', type=int, action='append', default=[], help='filter a team\'s IP/subnet')
    parser.add_argument('-o', type=str, default=DEFAULT_OUTPUT, help='Output directory')
    args = parser.parse_args()

    for i, pcap in enumerate(args.pcaps):
        if re.match(r'\d+', pcap):
            service = int(pcap)
            pcap = get_latest_pcap(service)
            if not pcap:
                print(f'No pcap found in "{TEAM_TRAFFIC_DIR}" for service {service}.')
                sys.exit(1)
            args.pcaps[i] = pcap

    if len(args.team) == 1 and len(args.ip) == 0 and len(args.port) == 0:
        # shortcut: use go tool
        print('invoking team-extractor tool (fast path)...')
        result = subprocess.run(
            ['/opt/pcap-splitter/team-extractor', '-o', args.o, '-t', str(args.team[0])] + args.pcaps
        )
        if result.returncode == 0:
            print('[OK]')
        else:
            print(f'[ERR] team-extractor failed with code {result.returncode}')
        return

    filters = []
    suffixes = []
    for team_id in args.team:
        filters.append(' or '.join(f'ip.src=={r} or ip.dst=={r}' for r in get_team_ranges(team_id)))
        suffixes.append(f'team{team_id}')
    for ip in args.ip:
        filters.append(f'ip.src=={ip} or ip.dst=={ip}')
        suffixes.append(f'ip{ip.replace("/", "-")}')
    if len(args.port) > 0:
        filters.append(' or '.join(f'tcp.port=={p} or udp.port=={p}' for p in args.port))
        suffixes.append('ports' + '+'.join(str(p) for p in args.port))
    if not filters:
        print('Please specify filters.')
        parser.print_help()
        sys.exit(1)
    filter_expr = '(' + ') and ('.join(filters) + ')' if len(filters) > 1 else filters[0]
    print(f'Filter expression: "{filter_expr}"')

    for fname in args.pcaps:
        output_fname = os.path.join(args.o,
                                    os.path.basename(fname).replace('.pcap', '') + '_' + '_'.join(suffixes) + '.pcap')
        print(f'Filtering "{fname}" => "{output_fname}" ...')
        cmd = get_tshark_cmd(fname, output_fname, filter_expr)
        result = subprocess.run(cmd)
        if result.returncode == 0:
            print('[OK]')
        else:
            print(f'[ERR] tshark failed with code {result.returncode}')


if __name__ == '__main__':
    main()
