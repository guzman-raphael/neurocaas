#!/bin/bash 
### Script that automates the deployment of analysis stacks from templates. 
set -e
scriptdir="$( cd "$( dirname "${BASH_SOURCE[0]}" )" >/dev/null 2>&1 && pwd )"
ncaprootdir="$(dirname "$(dirname "$scriptdir")")"

source "$scriptdir"/paths.sh
## Get the path to this particular file. 
## NOTE: Add the anaconda path if running as admin.  
source activate sam

## Input management: 
## Get the path to the directory where user data is stored: 
[ -d "$1" ] || { echo "ERROR: Must give path to analysis stack directory"; exit; }

PIPEDIR=$(get_abs_filename "$1")
## This can give us the stack name: 

PIPESTR=$(jq ".PipelineName" "$PIPEDIR"/stack_config_template.json)

PIPENAME=$(echo "$PIPESTR" | tr -d '"')

## Check this is alphanumeric: 
python "$scriptdir"/checkpath.py "$PIPENAME"

## Give the path to the root directory for ncap (we like absolute paths) 

cd $ncaprootdir/utils
stage=$(jq ".STAGE" "$PIPEDIR"/stack_config_template.json ) 
stagestr=$(echo $stage | tr -d '"')
echo $stagestr
python dev_builder.py $PIPEDIR/stack_config_template.json "$stagestr"
#if [ "$stagestr" == "develop" ] 
#
#then 
#    echo "development version."
#    python dev_builder.py $PIPEDIR/stack_config_template.json 
#elif [ "$stagestr" == "webdev" ]
#then
#    echo "web development version."
#    python webdev_builder.py $PIPEDIR/stack_config_template.json 
#elif [ "$stagestr" == "deploy" ]
#then
#    echo "deployment version."
#    python deploy_builder.py $PIPEDIR/stack_config_template.json 
#else
#    echo "not a valid option, ending"
#    exit 1
#fi 
# TODO bring up locanmf so this can get resolved. 
####
###### Run different deployment scripts based on version:
####version=$(jq ".PipelineVersion" "$PIPEDIR"/stack_config_template.json ) 
####versint=$(echo $version | tr -d '"')
####if [ "$versint" == "null" ] 
####then 
####    echo "latest version"
####    python config_handler_new.py $PIPEDIR/stack_config_template.json 
####elif [ "$versint" -eq 1 ]
####then
####    echo "version 1"
####    python config_handler.py $PIPEDIR/stack_config_template.json 
####else
####    echo "not a valid option, ending"
####    exit 1
####fi 

## We need to navigate to the pipeline directory because we have a relative path in our compilation code. 
cd $PIPEDIR

sam build -t compiled_template.json -m "$ncaprootdir"/protocols/requirements.txt --use-container

sam package --s3-bucket ctnsampackages --output-template-file compiled_packaged.yaml

sam deploy --template-file compiled_packaged.yaml --stack-name $PIPENAME --capabilities CAPABILITY_NAMED_IAM

aws s3 cp test_resources/computereport_1234567.json s3://$PIPENAME/logs/debug/
aws s3 cp test_resources/computereport_2345678.json s3://$PIPENAME/logs/debug/
