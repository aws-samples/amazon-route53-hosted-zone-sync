import json
import logging
import os
import boto3
  
log = logging.getLogger("handler")
log.setLevel(logging.INFO)

def lambda_handler(event, context):
    try:
        # We log the event received
        log.info("Received event: %s", json.dumps(event))
        
        # We obtain the environment variables
        private_hz_id = os.environ["PRIVATE_HOSTED_ZONE_ID"]
        aliases = os.environ["DONT_UPDATE"]
        # boto3 configuration
        r53 = boto3.client('route53')
        # We obtain the information of the event
        changes = event["detail"]["requestParameters"]["changeBatch"]["changes"]
        # We initialize the phz_changes variable
        phz_changes = []
        
        for c in changes:
            # We add the change if the alias is not part of the "DONT_UPDATE" list
            alias = (c["resourceRecordSet"]["name"].split("."))[0]
            if alias in str(aliases):
                log.info("Alias %s should not be updated", alias)
            else:
                # We need to capitalize all the keys in the map (to comply with the boto3 format) and add it to the Changes map
                c = update_change(c)
                phz_changes.append(c)

        # If we have updated the variable phz_changes, we update the Private Hosted Zone
        if len(phz_changes) > 0:
            log.info("To update: %s", phz_changes)
            updateHZ = r53.change_resource_record_sets(
                HostedZoneId=private_hz_id,
                ChangeBatch={
                    'Comment': 'Updating Private Hosted Zone from changes in Public Hosted Zone',
                    'Changes': phz_changes
                }
            )
            log.info("Successfully updated Private Hosted Zone %s", private_hz_id)
        else:
            log.info("No updates needed in Private Hosted Zone %s", private_hz_id)
        
    except Exception as e:
        log.exception("whoops")
        log.info(e)

def update_change(c):
    try:
        # Initialize new map (Change)
        newc = {}
        # We iterate over the keys
        for k, v in c.items():
            # ResourceRecordSet has a map, not a string
            if k == "resourceRecordSet":
                # We initialize the new ResourceRecordSet
                rrs = {}
                # We iterate over the keys
                for i, j in v.items():
                    # Special case 1: TTL
                    if i == "tTL":
                        rrs['TTL'] = j
                    
                    # Special case 2: GeoLocation, AliasTarget and CidrRoutingConfig have maps, not strings
                    elif i == "geoLocation" or i == "aliasTarget" or i == "cidrRoutingConfig":
                        keys = {}
                        for key, value in j.items():
                            keys[key.title()] = value
                        # Once we finish the iteration, we update resourceRecordSet
                        rrs['GeoLocation'] = keys
                    
                    # Special case 3: ResourceRecords has a list of maps
                    elif i == "resourceRecords":
                        for rs in j:
                            records = []
                            for key, value in rs.items():
                                records.append({key.title() : value})
                        # Once we finish the iteration over resourceRecords, we update resourceRecordSet
                        rrs["ResourceRecords"] = records
                    
                    # For other key-value pairs, we capitalize the first letter
                    else:
                        rrs[i.title()] = j
                
                # We create the new ResourceRecordSet map and we add it to the new Change
                newc['ResourceRecordSet'] = rrs
            
            else:
                # We capitalize the first letter of the Action
                newc[k.title()] = v
        
        # We return the new Change
        return newc
    
    except Exception as e:
        log.exception("whoops")
        log.info(e)