import logging
import os
import sys
import time
from pathlib import Path

import requests
from requests.auth import HTTPBasicAuth

BASE_URL: str = os.environ.get('API_URL', 'http://localhost:5000').rstrip('/')
CP_URL: str = os.environ.get('CP_URL', 'https://cp.ctf.saarland').rstrip('/')
FLOWER_URL: str = os.environ.get('FLOWER_URL', 'https://cp.ctf.saarland').rstrip('/')


class Api:
    def __init__(self, base_url: str = BASE_URL) -> None:
        self.base_url = base_url
        self.session = requests.Session()
        if 'API_USER' in os.environ and 'API_PASS' in os.environ:
            self.session.auth = HTTPBasicAuth(os.environ['API_USER'], os.environ['API_PASS'])

    def _check_response(self, response: requests.Response) -> None:
        if response.status_code != 200:
            logging.error(f'{response.request.method} {response.request.url} '
                          f'failed with status code {response.status_code}')
            if len(response.text) < 1024:
                logging.error(response.text)
            raise Exception()

    def run_test(self, fname: str) -> int:
        logging.info('Uploading package and scheduling test run ...')
        response = self.session.post(self.base_url + '/packages/test', json={'service_file': fname})
        self._check_response(response)
        data = response.json()
        logging.info(f'Test run "{data["ident"]}" ident has been scheduled')
        if data['message']:
            logging.info('Message from server: ' + data['message'])
        logging.info(f'Task:   {FLOWER_URL}/task/{data["task"]}')
        logging.info(f'Result: {CP_URL}/checker_results/view/{data["result_id"]}')
        return data['result_id']

    def get_result(self, result_id: int) -> dict:
        logging.info(f'... waiting for script to complete ...')
        response = self.session.get(f'{self.base_url}/checker_results/view/{result_id}',
                                headers={'Accept': 'application/json'})
        self._check_response(response)
        return response.json()

    def update_package(self, fname: str) -> None:
        logging.info('Uploading and deploying package ...')
        response = self.session.post(self.base_url + '/packages/update', json={'service_file': fname})
        self._check_response(response)
        for msg in response.json():
            logging.info(msg)


def report_result(result: dict) -> None:
    logging.info('-' * 80)
    if result['status'] == 'SUCCESS':
        logging.info(f'Status:  {result["status"]}')
    else:
        logging.error(f'Status:  {result["status"]}')
    logging.info(f'Runtime: {result["time"]} sec')
    logging.info(f'Message: {result["message"]}')
    logging.info('Script output:\n' + str(result['output']))
    logging.info('-' * 80)
    if result['status'] != 'SUCCESS':
        logging.error(f'Checker script failed ({result["status"]})')



def check(filename: str) -> dict:
    checker_dir = str(Path(filename).absolute().parent)
    api = Api()
    result_id = api.run_test(checker_dir)
    for _ in range(120):
        result = api.get_result(result_id)
        if result['status'] != 'PENDING':
            report_result(result)
            return result
        time.sleep(1)
    logging.error('No result after 120 seconds. Check the links above for more details.')
    raise Exception()


def deploy_unchecked(filename: str) -> None:
    checker_dir = str(Path(filename).absolute().parent)
    Api().update_package(checker_dir)  # TODO this is not necessarily the package we tested
    logging.info('Deployment complete.')


def deploy_checked(filename: str) -> None:
    result = check(filename)
    if result['status'] == 'SUCCESS':
        deploy_unchecked(filename)


if __name__ == '__main__':
    logging.basicConfig(level=logging.INFO, format="%(asctime)s [%(levelname)s]  %(message)s")
    try:
        if sys.argv[1] == 'check':
            check(sys.argv[2])
        elif sys.argv[1] == 'deploy-checked':
            deploy_checked(sys.argv[2])
        elif sys.argv[1] == 'deploy-unchecked':
            deploy_unchecked(sys.argv[2])
        else:
            logging.error(f'Unknown command: {sys.argv[1]}')
            sys.exit(1)
    except Exception as e:
        if str(e):
            logging.error(e)
        sys.exit(1)
