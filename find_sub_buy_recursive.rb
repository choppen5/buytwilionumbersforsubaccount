require 'twilio-ruby' 
require 'CSV'
account_sid = ENV['twilio_account_sid']        #'addyourTwilioaccountsidhere'
auth_token =  ENV['twilio_account_token']                            #'adddyourTwilioauthtokenhere'
   
@client = Twilio::REST::Client.new(account_sid, auth_token)
csv = "your_csvfile.csv"

timestamp = Time.now.to_f 
outcsv = "purchasednumbers.#{timestamp}.csv"
outerrors = "errorlog#{timestamp}"

outputfile = File.open(outcsv, "w")
errorlog   = File.open(outerrors, "w")

voiceurl ="http://www.yourcompany.com/twilio/api/VoiceInbound/PostCall?type=xml"
smsurl="http://www.yourcompany.net/twilio/api/SMSInbound/PostReceiveSMS"


def numbersforaccount (subsid, subauth, areacode, accountid, outputfile)

      subaccountnumbercount = 0
      @subclient = Twilio::REST::Client.new subsid, subauth 
      subnumbers =  @subclient.account.incoming_phone_numbers.list({})
      subaccountnumbercount = 0
      
      begin
        subnumbers.each do |incomingPhoneNumber| 

          incomingPhoneNumber = incomingPhoneNumber.phone_number
          puts "checking #{incomingPhoneNumber} for #{areacode}.." 
          numberlistareacode = /\+1(\d\d\d)/.match(incomingPhoneNumber)[1]  #will return 415 from +14155773411
          puts "parsed #{numberlistareacode} from #{incomingPhoneNumber}"

          if areacode == numberlistareacode
            #if this is a number matches our target area code, increment count 
            subaccountnumbercount = subaccountnumbercount + 1
            outputfile.puts("#{accountid}, #{subsid}, #{incomingPhoneNumber}")
          else 
            puts "this number #{incomingPhoneNumber} did not match our target #{areacode}, skipping"
          end
        end 
        
        subnumbers = subnumbers.next_page
      end while not subnumbers.empty?

    puts "found #{subaccountnumbercount} numbers for #{subsid}"
    return subaccountnumbercount
end

def buynumbers (accountsid, accountauth, amount, areacode, accountid, outputfile, errorlog, voiceurl, smsurl)

      @subclient = Twilio::REST::Client.new accountsid, accountauth 
      subnumbers =  @subclient.account.incoming_phone_numbers.list


      numbers = @subclient.account.available_phone_numbers.get('US').local.list({
        :area_code => areacode})
        
      boughtnumbers = 0

      numbers.each do |number|
        puts "Checking if #{boughtnumbers} is less than target #{amount}"
        if boughtnumbers < amount
          puts "buying number #{number.phone_number}"
          boughtnumber = @subclient.account.incoming_phone_numbers.create(
                 :phone_number => number.phone_number,
                 :sms_url => smsurl,        
                 :voice_url => voiceurl)

          puts "Success! Bought number  #{number.phone_number}! "
          outputfile.puts("#{accountid}, #{accountsid}, #{number.phone_number}")

          #print csv of subaccount here
          boughtnumbers = boughtnumbers +1
          #need error handler
        else
          break #don't bother going through the rest of the numbers, have what we need
        end
      end 
      return boughtnumbers
end 

def buymore (subaccountnumbercount, amount, accountsid, accountauth, areacode, accountid, outputfile, errorlog, voiceurl, smsurl)
    puts "Currently have #{subaccountnumbercount} numbers. Comaring to target #{amount}"
    totalboughtnumbers = subaccountnumbercount
    if subaccountnumbercount < amount 
        amount =  amount - subaccountnumbercount #target = 50, already have 40.. buy the difference
        puts "Buyng #{amount} more numbers.."
        
        numbersbought = buynumbers(accountsid, accountauth, amount, areacode, accountid, outputfile, errorlog, voiceurl, smsurl)
        totalboughtnumbers = numbersbought

        if numbersbought > 0 && numbersbought < amount
            #recursive function
            subaccountnumbercount =  subaccountnumbercount + numbersbought
            totalboughtnumbers = buymore(subaccountnumbercount, amount, accountsid, accountauth, areacode, accountid, outputfile, errorlog, voiceurl, smsurl)            

        end  
    else
      puts "have enough numbers now - #{subaccountnumbercount} numbers target = #{amount}"
    end
    return totalboughtnumbers
end 


### main control

CSV.foreach(csv) do |row|
  #remove duplicates in CSV by using the area code as a key and moving it to a new hash
  accountid = row[0] # get the id we will use a subaccount name
  areacode = row[1]
  amount    = row[2].to_i

  puts "accountid = #{accountid} areacode = #{areacode} amount = #{amount}"

  subsid = nil
  subauth = nil
  puts "searching for subaccount = #{accountid}"
  @client.accounts.list({:friendly_name => accountid}).each do |account| 
    subsid = account.sid
    subauth = account.auth_token
  end  

  if subsid
    puts "found subaccount #{subsid}"
  else    
    puts "couldn't find sub account #{accountid} - lets create it."
    account = @client.accounts.create(:friendly_name => accountid) 
    subsid = account.sid
    subauth = account.auth_token
  end

  puts "checking how many numbers that exist for acount in areacode #{areacode}.."
  numbsforaccount = numbersforaccount(subsid, subauth, areacode, accountid, outputfile)
  puts "found #{numbsforaccount} numbers for #{accountid} with areacode #{areacode}"

  #buymore: checks current amount, buys more for the area code. 
  totalnumbers = buymore(numbsforaccount, amount, subsid, subauth, areacode, accountid,outputfile, errorlog, voiceurl, smsurl) 
  totalnumbers = totalnumbers + numbsforaccount

  if totalnumbers < amount
    #we didn't get the amount of numbers we wanted for this area code.. log it and move on
    errorstring = "#{areacode},#{amount},#{totalnumbers},#{accountid},#{subsid},Failed to buy #{amount} numbers for #{areacode}. Subaccount #{accountid} #{subsid} currently has #{totalnumbers} in this area code."
    errorlog.puts(errorstring)
    puts(errorstring)
  end

end #end of CSV


