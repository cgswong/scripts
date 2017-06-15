#!/usr/bin/env python3

import sys
import os
import getpass
import configparser
import base64
import xml.etree.ElementTree as ET
import argparse
import logging
from logging.handlers import RotatingFileHandler
from bs4 import BeautifulSoup
import requests
import boto3
from termcolor import colored

def parse_args():
    """
    Parse command line arguments.

    :returns: Parsed arguments
    """
    parser = argparse.ArgumentParser(description='A command line tool to help with SAML access to the AWS token service.',
                                     formatter_class=argparse.ArgumentDefaultsHelpFormatter)
    parser.add_argument('-c', '--config-file',
                        action="store",
                        dest="aws_config",
                        help="AWS credentials file to use.",
                        default="~/.aws/credentials")

    parser.add_argument('--debug',
                        action="store_true",
                        dest="debug",
                        help="Turns on debug mode.")

    parser.add_argument('-d', '--domain',
                        action="store",
                        dest="domain",
                        help="Identity provider domain.",
                        default="amp.monsanto.com")

    parser.add_argument('-i', '--idp',
                        action="store",
                        dest="provider",
                        help="The type of SAML identity provider.",
                        default="pingid")

    parser.add_argument('-o', '--output',
                        action="store",
                        dest="output_format",
                        help="AWS output format to use for profile.",
                        default="json")

    parser.add_argument('-p', '--profile',
                        action="store",
                        dest="profile",
                        help="AWS profile to save temporary credentials.",
                        default="saml")

    parser.add_argument('-r', '--region',
                        action="store",
                        dest="region",
                        help="AWS region to use for profile.",
                        default="us-east-1")

    parser.add_argument('-s', '--skip-verify',
                        action="store_true",
                        dest="ssl_verify",
                        help="Flag to skip verification of server certificate.")

    return parser.parse_args()

def extract_form_data(response):
    """
    Extract, and process forms data.

    :param response: HTML string
    :type response: string

    :returns: newly processed HTML, form input name and value
    """
    soup = BeautifulSoup(response.text, "html.parser")
    action_url = soup.find('form')['action']
    form_inputs = soup.find('form').find_all('input')
    payload = {}
    for element in form_inputs:
        if element['type'] == 'hidden':
            input_name = element['name']
            input_value = element['value']
            payload[input_name] = input_value

    return action_url, payload

def mfa(session, html, ssl_verify=True, timeout_value=30):
    """
    Handle MFA via device swipe.

    :param session: Requests session
    :type session: Requests object
    :param html: HTML response
    :type html: Response object
    :param ssl_verify: Flag to user SSL verification
    :type ssl_verify: boolean
    :param ssl_verify: Timeout value
    :type timeout_value: number

    :returns: Parsed URL and payload response from MFA session
    """
    logger.debug("HTML passed: \n%s", html.text)
    # Process response on starting MFA
    action_url, payload = extract_form_data(html)
    # Start MFA
    rsp = session.post(action_url,
                       data=payload,
                       verify=ssl_verify,
                       timeout=timeout_value)
    # Process response on starting MFA
    mfa_url, mfa_payload = extract_form_data(rsp)
    # Send request to initiate MFA
    mfa_rsp = session.post(mfa_url,
                           data=mfa_payload,
                           verify=ssl_verify,
                           timeout=timeout_value)
    print(colored('\n*** AUTHENTICATE WITH MFA NOW ***', 'green'))

    # Process response to send back to IdP, and send it
    idp_url, idp_payload = extract_form_data(mfa_rsp)
    idp_rsp = session.post(idp_url,
                           data=idp_payload,
                           verify=ssl_verify,
                           timeout=timeout_value)

    # Process response and send back to IdP
    post_url, post_payload = extract_form_data(idp_rsp)
    post_rsp = session.post(post_url,
                            data=post_payload,
                            verify=ssl_verify,
                            timeout=timeout_value)
    return BeautifulSoup(post_rsp.text, "html.parser")

def ping_auth(session, url, username, password, ssl_verify=True, timeout_value=30):
    """
    PingID validation using username and password and return the new page.

    :param session: Requests session
    :type session: Requests object
    :param url: Initial URL for PingID login
    :type url: string
    :param username: User name
    :type username: string
    :param password: User password
    :type password: string
    :param ssl_verify: Flag to user SSL verification
    :type ssl_verify: boolean
    :param ssl_verify: Timeout value
    :type timeout_value: number

    :returns: HTML response ojbect
    """
    # Some PingID implementations are different.
    # Customizated URL here handles this unfortunate situation.
    logon_url = "https://sso.connect.pingidentity.com/sso/sp/initsso?saasid=d6ebf792-3796-4686-b44b-ed7654f29a66&idpid=monsanto-aws2-prod"
    # Send HTTP GET request to the IdP initiated URL endpoint.
    # Process the response for instructions on where to POST and
    # sending the username and password.
    init_resp = session.get(logon_url, verify=ssl_verify, timeout=timeout_value)
    init_soup = BeautifulSoup(init_resp.text, "html.parser")
    idp_action = init_soup.find('form')['action']
    form_username = init_soup.find('form').find('input', attrs={'id':"username"})['name']
    form_password = init_soup.find('form').find('input', attrs={'id':"password"})['name']
    idp_url = url + idp_action

    # Submit the IdP login form with the POST data and return parsed content
    payload = {form_username: username, form_password: password}
    rsp = session.post(idp_url, data=payload, verify=ssl_verify, timeout=timeout_value)
    logger.debug("PingID URL: %s", rsp.url)
    logger.debug("PingID response: \n%s", rsp.text)
    if rsp.status_code != 200:
        logger.debug("PingID status code: %s", rsp.status_code)
        logger.debug("PingID response: \n%s", rsp.text)
        print(colored('Login failed with status code: {}', 'red').format(rsp.status_code))

    return rsp

def assume_role(saml_xml, principal_arn, role_arn):
    """
    Use SAML assertion to get an AWS STS token using AssumeRolewithSAML.

    :param saml_xml: SAML XML string
    :type saml_xml: string
    :param principal_arn: ARN for provider
    :type principal_arn: string
    :param role_arn: ARN for role
    :type role_arn: string

    :returns: token
    """
    sts = boto3.client('sts').assume_role_with_saml(RoleArn=role_arn,
                                                    PrincipalArn=principal_arn,
                                                    SAMLAssertion=saml_xml)

    access_key = sts['Credentials']['AccessKeyId']
    secret_key = sts['Credentials']['SecretAccessKey']
    token = sts['Credentials']['SessionToken']
    expiration = sts['Credentials']['Expiration']
    print("")
    print('----------------------------------------------------------------')
    print('Copy/paste in shell to setup environment:\n')
    print(colored('\texport AWS_ACCESS_KEY_ID={}', 'green').format(access_key))
    print(colored('\texport AWS_SECRET_ACCESS_KEY={}', 'green').format(secret_key))
    print(colored('\texport AWS_SESSION_TOKEN="{}"', 'green').format(token))
    print(colored('\texport AWS_SESSION_EXPIRATION="{}"', 'green').format(expiration))
    print('----------------------------------------------------------------')

    return access_key, secret_key, token, expiration

def get_roles(saml_xml):
    """
    Extract SAML roles from SAML assertion XML

    :param saml_xml: SAML XML string
    :type saml_xml: string

    :returns: AWS roles
    """
    # Parse the returned assertion and extract the authorized AWS roles
    roles = []
    root = ET.fromstring(base64.b64decode(saml_xml))
    for attr in root.iter('{urn:oasis:names:tc:SAML:2.0:assertion}Attribute'):
        if attr.get('Name') == 'https://aws.amazon.com/SAML/Attributes/Role':
            for val in attr.iter('{urn:oasis:names:tc:SAML:2.0:assertion}AttributeValue'):
                roles.append(val.text)

    logger.debug("Roles found: %s", roles)
    return roles

def select_role(roles):
    """
    Get AWS role to use.
    """
    # If more than one role, ask which, otherwise just proceed
    print("")
    if len(roles) > 1:
        i = 1
        print("Please choose role to assume (0 to exit):")
        for awsrole in roles:
            print('[', i, ']: ', awsrole.split(',')[0])
            i += 1

        selected_role = input("Selection: ")

        # Basic sanity check of input
        while int(selected_role) > len(roles) or int(selected_role) < 1:
            if int(selected_role) == 0:
                print("Exit selected.")
                sys.exit(0)
            print(colored('Invalid role index selected, please try again.', 'red'))
            selected_role = input("Selection: ")

        role_arn = roles[int(selected_role) - 1].split(',')[0]
        principal_arn = roles[int(selected_role) - 1].split(',')[1]
    else:
        role_arn = roles[0].split(',')[0]
        principal_arn = roles[0].split(',')[1]

    logger.debug("Principal ARN: %s and Role ARN: %s", principal_arn, role_arn)
    return principal_arn, role_arn

def write_credentials(profile, access_key, secret_key, token_expire, token=None,
                      aws_credfile="~/.aws/credentials",
                      region="us-east-1",
                      output="json"):
    """
    Write AWS credentials to file.

    :param profile: Name of AWS profile
    :type profile: string
    :param access_key: AWS access key
    :type access_key: string
    :param secret_key: AWS secret key
    :type secret_key: string
    :param token_expire: Token expiration date
    :type token_expire: string
    :param token: Temporary AWS token
    :type token: string
    :param configile: Name of AWS configuration file
    :type configile: string
    :param region: AWS region
    :type region: string
    :param output: Output format
    :type output: string
    """
    # Write the AWS STS token into the AWS credential file
    credfile = os.path.expanduser(aws_credfile)
    os.makedirs(os.path.dirname(credfile), exist_ok=True)

    # Read in the existing config file
    config = configparser.ConfigParser()
    if os.path.exists(credfile):
        config.read(credfile)

    # Put the credentials into a specific profile instead of clobbering
    # the default credentials.
    logger.debug("Output format: %s", output)
    logger.debug("Region: %s", region)
    logger.debug("Profile: %s", profile)
    logger.debug("Credential file: %s", credfile)
    if not config.has_section(profile):
        config.add_section(profile)

    config.set(profile, 'output', output)
    config.set(profile, 'region', region)
    config.set(profile, 'aws_access_key_id', access_key)
    config.set(profile, 'aws_secret_access_key', secret_key)
    if token:
        config.set(profile, 'aws_session_token', token)
        config.set(profile, 'aws_security_token', token)

    # Write the updated config file
    try:
        with open(credfile, 'w') as configfile:
            config.write(configfile)
    except configparser.DuplicateSectionError:
        logger.error("Profile section %s already exists.", profile)
        sys.exit(1)
    except:
        logger.error("Unexpected error: %s", sys.exc_info()[0])
        raise

    configfile.close()

    # Give the user some basic info as to what has just happened
    print("")
    print('----------------------------------------------------------------')
    print(colored('AWS configuration file: {}', 'green').format(credfile))
    print(colored('Profile section: {}', 'green').format(profile))
    print(colored('Token expiration: {}', 'green').format(token_expire))
    print("")
    print(colored('After this time you may safely rerun this script to refresh your access key pair.', 'green'))
    print(colored('To use this credential call the AWS CLI with the "--profile" option (e.g. "aws --profile={} ec2 describe-instances").', 'green').format(profile))
    print('----------------------------------------------------------------')
    print("")

def saml2():
    """
    Use SAML2 for authentication and retrieval of assertions.
    """
    # Default AWS region that script will connect for all API calls.
    region = args.region

    # AWS CLI output format that will be configured in the SAML profile
    # (affects subsequent CLI calls).
    output_format = args.output_format

    # File to store the temp credentials under the SAML profile
    aws_config = args.aws_config

    # SSL certificate verification: Whether or not strict certificate
    # verification is done, False should only be used for dev/test
    if args.ssl_verify:
        ssl_verify = False
    else:
        ssl_verify = True

    # Provider to use
    provider = args.provider

    # Profile under which to store credentials
    profile = args.profile

    # Identity provider base URL. Typically looks something like:
    # 'https://<fqdn>:<port>/idp/startSSO.ping?PartnerSpId=urn:amazon:webservices'
    # Though sometimes everything after the base domain is dyanmically added.
    idp_url = "https://" + args.domain

    if args.debug:
        logger.setLevel(logging.DEBUG)
    else:
        logger.setLevel(logging.INFO)

    # Get the federated credentials from the user
    username = input("Username: ")
    password = getpass.getpass()

    # Initiate session handler and authenticate user
    session = requests.Session()

    if provider == "pingid":
        logger.info("IdP provider specified: %s", provider)
        rsp = ping_auth(session, idp_url, username, password)
    else:
        print(colored('{} is not a valid IdP. Please use pingid.', 'red').format(provider))
        logger.info("Not a valid IdP. Please use pingid.")
        sys.exit(1)

    # Check for MFA
    logger.info("Getting SAML asssertion.")
    logger.debug("IdP provider %s form response: \n%s", provider, rsp.text)
    logger.info("IdP provider %s form status code: %s", provider, rsp.status_code)
    logger.info("IdP provider %s form history: %s", provider, rsp.history)
    if len(rsp.history) > 0:
        if provider == "pingid":
            logger.info("Redirecting to use MFA.")
            saml_assertion = mfa(session, rsp, ssl_verify)
    else:
        # POST the form to IdP, get SAML assertion
        saml_assertion = mfa(session, rsp, ssl_verify)
        ##idp_rsp = session.post(rsp.text, data={"pf.username": username, "pf.pass": password})
        ##saml_assertion = BeautifulSoup(idp_rsp.text, "html.parser")

    # Overwrite and delete the credential variables for safety
    username = '##############################################'
    password = '##############################################'
    del username
    del password

    # Parse SAML assertion
    logger.debug("SAML response: \n%s", saml_assertion.text)
    assertion = saml_assertion.find('input', attrs={'name':"SAMLResponse"})['value']
    logger.debug("SAML Assertion: %s", assertion)

    logger.info("Getting AWS Roles.")
    principal_arn, role_arn = select_role(get_roles(assertion))

    # Obtain temporary credentials and update configuration file.
    logger.info("Using STS to get temporary credentials.")
    access_key, secret_key, token, expiration = assume_role(assertion, principal_arn, role_arn)
    logger.info("Writing to AWS configuration file %s.", aws_config)
    write_credentials(profile, access_key, secret_key, expiration, token, aws_config, region, output_format)

if __name__ == "__main__":
    # Setup logging
    logger = logging.getLogger()
    handler = RotatingFileHandler(filename="/tmp/" + os.path.splitext(os.path.basename(__file__))[0] + ".log",
                                  maxBytes=5242880,
                                  backupCount=3)
    formatter = logging.Formatter('%(asctime)s [%(filename)s:%(lineno)s - %(funcName)20s] %(levelname)-8s %(message)s')
    handler.setFormatter(formatter)
    logger.addHandler(handler)

    args = parse_args()

    saml2()
