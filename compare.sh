#!/bin/bash


VMAILPATH="/var/vmail"
DISKACCOUNTS="diskaccounts.list"
ACTIVEACCOUNTS="activeaccounts.list"

echo -n "Getting account on disk...  "
ls --color=never -ls $VMAILPATH | awk '{print $10}' > /tmp/$DISKACCOUNTS
amountdisk=$(cat /tmp/$DISKACCOUNTS | wc -l)
echo "$amountdisk"

echo -n "Getting the postfix accounts from MYSQL...  "
mysql -B --disable-column-names -e 'select local_part from postfix.mailbox;' | sort | uniq > /tmp/$ACTIVEACCOUNTS
amountmysql=$(cat /tmp/$ACTIVEACCOUNTS | wc -l)

echo "$amountmysql"

echo "$(expr $amountdisk - $amountmysql) mailboxes could be deleted."

echo "Checking against the MySQL database...."

echo "number|mailbox|last access|size" > /tmp/free.list

while IFS= read -r line
do
	((process+=1))

	line=$(echo -e "$line" | sed "s,\x1B\[[0-9;]*[a-zA-Z],,g")
	if grep -Fxq "$line" /tmp/activeaccounts.list; then continue; fi

	# Row number
	((count+=1))

	#check if maildir exists before calculating the size.
	[ ! -d "$VMAILPATH/$line/cur/" ] && { continue; } # echo "$count|$line|N/A|0K"

	# Add the KB to the total for a nice summary
	((space+=$(du -s /var/vmail/$line | awk '{print $1}')))

	# Show on screen & save to file.
	echo -ne "$(echo $space | awk '{ total = $1 / 1024 ; print total "MB" }') can be freed up already!    ($process/$amountdisk)       "\\r
	
	#echo "$count|$line|$(date -d @$(stat --format=%Y $VMAILPATH/$line/cur) '+%m-%Y')|$(du -sh /var/vmail/$line | awk '{print $1}')"
	echo "$count|$line|$(date -d @$(stat --format=%Y $VMAILPATH/$line/cur) '+%m-%Y')|$(du -sh /var/vmail/$line | awk '{print $1}')" >> /tmp/free.list
	
done < "$DISKACCOUNTS"

space=$(echo $space | awk '{ total = $1 / 1024 ; print total "MB" }')
echo "|$(date)|Total space|$space" >> /tmp/free.list

echo -e "\nDone! Result in file /tmp/free.list"
