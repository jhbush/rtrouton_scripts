#!/bin/bash

##########################################################################################
# 	Scripts Delete Script for Jamf Pro
#
#
#	Usage: Call script with the following four parameters
#			- a text file of the Jamf Pro script IDs you wish to delete
#
#	You will be prompted for:
#			- The URL of the appropriate Jamf Pro server
#			- Username for an account on the Jamf Pro server with sufficient API privileges
#			- Password for the account on the Jamf Pro server
#
#	The script will:
#			- Delete the specified scripts using their Jamf Pro script IDs
#			- Generate a report of all successfully deleted scripts in TSV format
#
#	Example:	./delete_Jamf_Pro_Scripts.sh jamf_pro_id_numbers.txt
#
##########################################################################################

filename="$1"
ERROR=0
report_file="$(mktemp).tsv"

# If you're on Jamf Pro 10.34.2 or earlier, which doesn't support using Bearer Tokens
# for Classic API authentication, set the NoBearerToken variable to the following value
# as shown below:
#
# yes
#
# NoBearerToken="yes"
#
# If you're on Jamf Pro 10.35.0 or later, which does support using Bearer Tokens
# for Classic API authentication, set the NoBearerToken variable to the following value
# as shown below:
#
# NoBearerToken=""

NoBearerToken=""

GetJamfProAPIToken() {

# This function uses Basic Authentication to get a new bearer token for API authentication.

# Use user account's username and password credentials with Basic Authorization to request a bearer token.

if [[ $(/usr/bin/sw_vers -productVersion | awk -F . '{print $1}') -lt 12 ]]; then
   api_token=$(/usr/bin/curl -X POST --silent -u "${jamfpro_user}:${jamfpro_password}" "${jamfpro_url}/api/v1/auth/token" | python -c 'import sys, json; print json.load(sys.stdin)["token"]')
else
   api_token=$(/usr/bin/curl -X POST --silent -u "${jamfpro_user}:${jamfpro_password}" "${jamfpro_url}/api/v1/auth/token" | plutil -extract token raw -)
fi

}

APITokenValidCheck() {

# Verify that API authentication is using a valid token by running an API command
# which displays the authorization details associated with the current API user. 
# The API call will only return the HTTP status code.

api_authentication_check=$(/usr/bin/curl --write-out %{http_code} --silent --output /dev/null "${jamfpro_url}/api/v1/auth" --request GET --header "Authorization: Bearer ${api_token}")

}

CheckAndRenewAPIToken() {

# Verify that API authentication is using a valid token by running an API command
# which displays the authorization details associated with the current API user. 
# The API call will only return the HTTP status code.

APITokenValidCheck

# If the api_authentication_check has a value of 200, that means that the current
# bearer token is valid and can be used to authenticate an API call.


if [[ ${api_authentication_check} == 200 ]]; then

# If the current bearer token is valid, it is used to connect to the keep-alive endpoint. This will
# trigger the issuing of a new bearer token and the invalidation of the previous one.

      if [[ $(/usr/bin/sw_vers -productVersion | awk -F . '{print $1}') -lt 12 ]]; then
         api_token=$(/usr/bin/curl "${jamfpro_url}/api/v1/auth/keep-alive" --silent --request POST --header "Authorization: Bearer ${api_token}" | python -c 'import sys, json; print json.load(sys.stdin)["token"]')
      else
         api_token=$(/usr/bin/curl "${jamfpro_url}/api/v1/auth/keep-alive" --silent --request POST --header "Authorization: Bearer ${api_token}" | plutil -extract token raw -)
      fi

else

# If the current bearer token is not valid, this will trigger the issuing of a new bearer token
# using Basic Authentication.

   GetJamfProAPIToken
fi
}

InvalidateToken() {

# Verify that API authentication is using a valid token by running an API command
# which displays the authorization details associated with the current API user. 
# The API call will only return the HTTP status code.

APITokenValidCheck

# If the api_authentication_check has a value of 200, that means that the current
# bearer token is valid and can be used to authenticate an API call.

if [[ ${api_authentication_check} == 200 ]]; then

# If the current bearer token is valid, an API call is sent to invalidate the token.

      authToken=$(/usr/bin/curl "${jamfpro_url}/api/v1/auth/invalidate-token" --silent  --header "Authorization: Bearer ${api_token}" -X POST)
      
# Explicitly set value for the api_token variable to null.

      api_token=""

fi
}

if [[ -n $filename && -r $filename ]]; then

	# If you choose to hardcode API information into the script, uncomment the lines below
	# and set one or more of the following values:
	#
	# The username for an account on the Jamf Pro server with sufficient API privileges
	# The password for the account
	# The Jamf Pro URL

	#jamfpro_url=""	## Set the Jamf Pro URL here if you want it hardcoded.
	#jamfpro_user=""		## Set the username here if you want it hardcoded.
	#jamfpro_password=""		## Set the password here if you want it hardcoded.


	# If you do not want to hardcode API information into the script, you can also store
	# these values in a ~/Library/Preferences/com.github.jamfpro-info.plist file.
	#
	# To create the file and set the values, run the following commands and substitute
	# your own values where appropriate:
	#
	# To store the Jamf Pro URL in the plist file:
	# defaults write com.github.jamfpro-info jamfpro_url https://jamf.pro.server.goes.here:port_number_goes_here
	#
	# To store the account username in the plist file:
	# defaults write com.github.jamfpro-info jamfpro_user account_username_goes_here
	#
	# To store the account password in the plist file:
	# defaults write com.github.jamfpro-info jamfpro_password account_password_goes_here
	#
	# If the com.github.jamfpro-info.plist file is available, the script will read in the
	# relevant information from the plist file.

	if [[ -f "$HOME/Library/Preferences/com.github.jamfpro-info.plist" ]]; then

	     if [[ -z "$jamfpro_url" ]]; then
	          jamfpro_url=$(defaults read $HOME/Library/Preferences/com.github.jamfpro-info jamfpro_url)
	     fi

	     if [[ -z "$jamfpro_user" ]]; then
	          jamfpro_user=$(defaults read $HOME/Library/Preferences/com.github.jamfpro-info jamfpro_user)
	     fi

	     if [[ -z "$jamfpro_password" ]]; then
	          jamfpro_password=$(defaults read $HOME/Library/Preferences/com.github.jamfpro-info jamfpro_password)
	     fi

	fi

	# If the Jamf Pro URL, the account username or the account password aren't available
	# otherwise, you will be prompted to enter the requested URL or account credentials.

	if [[ -z "$jamfpro_url" ]]; then
	     read -p "Please enter your Jamf Pro server URL : " jamfpro_url
	fi

	if [[ -z "$jamfpro_user" ]]; then
	     read -p "Please enter your Jamf Pro user account : " jamfpro_user
	fi

	if [[ -z "$jamfpro_password" ]]; then
	     read -p "Please enter the password for the $jamfpro_user account: " -s jamfpro_password
	fi

	echo ""

	# Remove the trailing slash from the Jamf Pro URL if needed.
	jamfpro_url=${jamfpro_url%%/}

	# Set up the Jamf Pro Computer ID URL
	jamfproIDURL="${jamfpro_url}/JSSResource/scripts/id"
	
	# If configured to get one, get a Jamf Pro API Bearer Token
	
	if [[ -z "$NoBearerToken" ]]; then
   	   GetJamfProAPIToken
	fi

	while read -r ScriptsID
	do

		# Verify that the input is a number. All Jamf Pro
		# IDs are positive numbers, so any other input will
		# not be a valid Jamf Pro ID.

		if [[ "$ScriptsID" =~ ^[0-9]+$ ]]; then
		
		  if [[ ! -f "$report_file" ]]; then
			/usr/bin/touch "$report_file"
			printf "Deleted Script ID Number\tDeleted Script Name\n" > "$report_file"
		  fi

		  # Get script display name
		  
		  if [[ -z "$NoBearerToken" ]]; then
		  	  CheckAndRenewAPIToken
		      ScriptsName=$(/usr/bin/curl -s --header "Authorization: Bearer ${api_token}" -H "Accept: application/xml" "${jamfpro_url}/JSSResource/scripts/id/$ScriptsID" | xmllint --xpath '//script/name/text()' - 2>/dev/null)
		  else
		  	  ScriptsName=$(/usr/bin/curl -su "${jamfpro_user}:${jamfpro_password}" -H "Accept: application/xml" "${jamfpro_url}/JSSResource/scripts/id/$ScriptsID" | xmllint --xpath '//script/name/text()' - 2>/dev/null)
		  fi
		  
		  # Remove comment from line below to preview
		  # the results of the deletion command.

		  echo -e "Deleting $ScriptsName - script ID $ScriptsID."

		  # Remove comments from lines below to actually run
		  # the deletion command.

		  #if [[ -z "$NoBearerToken" ]]; then
		  #	  CheckAndRenewAPIToken
		  #    /usr/bin/curl -s --header "Authorization: Bearer ${api_token}" "${jamfproIDURL}/$ScriptsID" -X DELETE
		  #else
		  #	  /usr/bin/curl -su "${jamfpro_user}:${jamfpro_password}" "${jamfproIDURL}/$ScriptsID" -X DELETE
		  #fi
		  
		  if [[ $? -eq 0 ]]; then
	         printf "$ScriptsID\t %s\n" "$ScriptsName" >> "$report_file"
	         echo -e "\nDeleted $ScriptsName - script ID $ScriptsID.\n"
		  else
	         echo -e "\nERROR! Failed to delete $ScriptsName - script ID $ScriptsID.\n"
		  fi

		else
		   echo "All Jamf Pro IDs are expressed as numbers. The following input is not a number: $ScriptsID"
		fi
	done < "$filename"

else
	echo "Input file does not exist or is not readable"
	ERROR=1
fi

if [[ -f "$report_file" ]]; then
     echo "Report on deleted scripts available here: $report_file"
fi

exit "$ERROR"