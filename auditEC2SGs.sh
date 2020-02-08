#!/bin/bash
# Purpose: Retrieve comma-separated-value list of associations between
# EC2 Instances, Elastice Network Interfaces, Security Groups, and allowed IP/port ranges
# ec2.InstanceId,ec2.Name,eni.NetworkInterfaceId,eni.Description,sg.GroupId,sg.Name,sg.AllowedIp,sg.PortRange

### Source ${PROFILE} and ${REGION} from bashrc
source ~/.bashrc

aws ec2 describe-security-groups --profile ${PROFILE} --region ${REGION} > sgDetails.json
cat sgDetails.json | jq -r '.SecurityGroups[] | [.GroupId,.GroupName,([.IpPermissions[].IpRanges[].CidrIp] | join(" "))] | join(",")' > sgList.out
aws ec2 describe-network-interfaces --profile ${PROFILE} --region ${REGION} | jq -r '.NetworkInterfaces[] | [.NetworkInterfaceId,.Description,([.Groups[].GroupId] | join(" "))] | join(",")' > eniList.out
aws ec2 describe-instances --profile ${PROFILE} --region ${REGION} | jq -r '.Reservations[].Instances[] | [.InstanceId,(.Tags[] | select(.Key == "Name").Value),([.NetworkInterfaces[].NetworkInterfaceId] | join(" ")),([.SecurityGroups[].GroupId] | join(" "))] | join(",")' > ec2List.out

while read line; do
  INSTANCE_ID=$(echo $line | awk -F ',' '{print $1}')
  NAME=$(echo $line | awk -F ',' '{print $2}')
  NETWORK_INTERFACE_IDS=$(echo $line | awk -F ',' '{print $3}')
  SECURITY_GROUP_IDS=$(echo $line | awk -F ',' '{print $4}')
  for NETWORK_INTERFACE_ID in ${NETWORK_INTERFACE_IDS}; do
    ENI_DESCRIPTION=$(grep "^${NETWORK_INTERFACE_ID}," eniList.out | awk -F ',' '{print $2}')
    ENI_SECURITY_GROUP_IDS=$(grep "^${NETWORK_INTERFACE_ID}," eniList.out | awk -F ',' '{print $3}')
    for ENI_SECURITY_GROUP_ID in ${ENI_SECURITY_GROUP_IDS}; do
      SG_NAME=$(grep "^${ENI_SECURITY_GROUP_ID}," sgList.out | awk -F ',' '{print $2}')
      SG_ALLOWED_IPS=$(grep "^${ENI_SECURITY_GROUP_ID}," sgList.out | awk -F ',' '{print $3}')
      for SG_ALLOWED_IP in ${SG_ALLOWED_IPS}; do
        FROM_TO_PORTS=$(cat sgDetails.json | jq -r ".SecurityGroups[] | select(.GroupId == \"${ENI_SECURITY_GROUP_ID}\").IpPermissions[] | [(select(.IpRanges[].CidrIp == \"${SG_ALLOWED_IP}\") | [(.FromPort | tostring),(.ToPort | tostring)] | join(\",\"))] | join(\" \")")
        for FROM_TO_PORT in ${FROM_TO_PORTS}; do
          FROM_PORT=$(echo "${FROM_TO_PORT}" | awk -F ',' '{print $1}')
          TO_PORT=$(echo "${FROM_TO_PORT}" | awk -F ',' '{print $2}')
          if [[ "${FROM_PORT}" == "${TO_PORT}" ]]; then
            PORT_RANGE=${FROM_PORT}
          else
            PORT_RANGE="${FROM_PORT}-${TO_PORT}"
          fi
          if [[ "${PORT_RANGE}" == "null" ]]; then PORT_RANGE="All"; fi
          echo "${INSTANCE_ID},${NAME},${NETWORK_INTERFACE_ID},${ENI_DESCRIPTION},${ENI_SECURITY_GROUP_ID},${SG_NAME},${SG_ALLOWED_IP},${PORT_RANGE}"
        done
      done
    done
  done
  for SECURITY_GROUP_ID in ${SECURITY_GROUP_IDS}; do
    SG_NAME=$(grep "^${SECURITY_GROUP_ID}," sgList.out | awk -F ',' '{print $2}')
    SG_ALLOWED_IPS=$(grep "^${SECURITY_GROUP_ID}," sgList.out | awk -F ',' '{print $3}')
    for SG_ALLOWED_IP in ${SG_ALLOWED_IPS}; do
      FROM_TO_PORTS=$(cat sgDetails.json | jq -r ".SecurityGroups[] | select(.GroupId == \"${SECURITY_GROUP_ID}\").IpPermissions[] | [(select(.IpRanges[].CidrIp == \"${SG_ALLOWED_IP}\") | [(.FromPort | tostring),(.ToPort | tostring)] | join(\",\"))] | join(\" \")")
      for FROM_TO_PORT in ${FROM_TO_PORTS}; do
        FROM_PORT=$(echo "${FROM_TO_PORT}" | awk -F ',' '{print $1}')
        TO_PORT=$(echo "${FROM_TO_PORT}" | awk -F ',' '{print $2}')
        if [[ "${FROM_PORT}" == "${TO_PORT}" ]]; then
          PORT_RANGE=${FROM_PORT}
        else
          PORT_RANGE="${FROM_PORT}-${TO_PORT}"
        fi
        if [[ "${PORT_RANGE}" == "null" ]]; then PORT_RANGE="All"; fi
        echo "${INSTANCE_ID},${NAME},,,${ENI_SECURITY_GROUP_ID},${SG_NAME},${SG_ALLOWED_IP},${PORT_RANGE}"
      done
    done
  done
done < ec2List.out
while read line; do
  NETWORK_INTERFACE_ID=$(echo $line | awk -F ',' '{print $1}')
  if ! grep -q ${NETWORK_INTERFACE_ID} ec2List.out; then
    ENI_DESCRIPTION=$(grep "^${NETWORK_INTERFACE_ID}," eniList.out | awk -F ',' '{print $2}')
    ENI_SECURITY_GROUP_IDS=$(grep "^${NETWORK_INTERFACE_ID}," eniList.out | awk -F ',' '{print $3}')
    for ENI_SECURITY_GROUP_ID in ${ENI_SECURITY_GROUP_IDS}; do
      SG_NAME=$(grep "^${ENI_SECURITY_GROUP_ID}," sgList.out | awk -F ',' '{print $2}')
      SG_ALLOWED_IPS=$(grep "^${ENI_SECURITY_GROUP_ID}," sgList.out | awk -F ',' '{print $3}')
      for SG_ALLOWED_IP in ${SG_ALLOWED_IPS}; do
        FROM_TO_PORTS=$(cat sgDetails.json | jq -r ".SecurityGroups[] | select(.GroupId == \"${ENI_SECURITY_GROUP_ID}\").IpPermissions[] | [(select(.IpRanges[].CidrIp == \"${SG_ALLOWED_IP}\") | [(.FromPort | tostring),(.ToPort | tostring)] | join(\",\"))] | join(\" \")")
        for FROM_TO_PORT in ${FROM_TO_PORTS}; do
          FROM_PORT=$(echo "${FROM_TO_PORT}" | awk -F ',' '{print $1}')
          TO_PORT=$(echo "${FROM_TO_PORT}" | awk -F ',' '{print $2}')
          if [[ "${FROM_PORT}" == "${TO_PORT}" ]]; then
            PORT_RANGE=${FROM_PORT}
          else
            PORT_RANGE="${FROM_PORT}-${TO_PORT}"
          fi
          if [[ "${PORT_RANGE}" == "null" ]]; then PORT_RANGE="All"; fi
          echo "${INSTANCE_ID},${NAME},${NETWORK_INTERFACE_ID},${ENI_DESCRIPTION},${ENI_SECURITY_GROUP_ID},${SG_NAME},${SG_ALLOWED_IP},${PORT_RANGE}"
        done
      done
    done
  fi
done < eniList.out


rm sgList.out eniList.out ec2List.out
