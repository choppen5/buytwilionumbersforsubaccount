A script to take a input csv file in the following format:

subaccountname,areacode,10

The script will:
- look for a subaccount with that name
- create it if it doesn't exist
- buy as many numbers as specified in the the third column
- log the output for every existing or purchased number in a CSV
- log errors if the amount of numbers wanted for the area code does not exist

To setup:
- have Ruby intalled
- gem install twilio-ruby 

Config:
- set the following varilables:
	- account_sid 
	- auth_token
	- voiceurl (to be added to purchased numbers)
	- smsurl (to be added to purchased numbers)
	- csv  (input file)
