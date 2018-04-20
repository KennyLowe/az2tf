tfp="azurerm_route_table"
prefixa="rtb"
if [ "$1" != "" ]; then
    rgsource=$1
else
    echo -n "Enter name of Resource Group [$rgsource] > "
    read response
    if [ -n "$response" ]; then
        rgsource=$response
    fi
fi
azr=`az network route-table list -g $rgsource`
count=`echo $azr | jq '. | length'`
if [ "$count" != "0" ]; then
count=`expr $count - 1`
for i in `seq 0 $count`; do
    name=`echo $azr | jq ".[(${i})].name" | tr -d '"'`
    rg=`echo $azr | jq ".[(${i})].resourceGroup" | tr -d '"'`
    id=`echo $azr | jq ".[(${i})].id" | tr -d '"'`
    loc=`echo $azr | jq ".[(${i})].location" | tr -d '"'`
    routes=`echo $azr | jq ".[(${i})].routes"`
    prefix=`printf "%s_%s" $prefixa $rg`

    printf "resource \"%s\" \"%s__%s\" {\n" $tfp $rg $name > $prefix-$name.tf
    printf "\t name = \"%s\"\n" $name >> $prefix-$name.tf
    printf "\t location = \"%s\"\n" $loc >> $prefix-$name.tf
    printf "\t resource_group_name = \"%s\"\n" $rg >> $prefix-$name.tf
    #
    # Interate routes
    #
    rcount=`echo $routes | jq '. | length'`
    if [ "$rcount" -gt "0" ]; then
        rcount=`expr $rcount - 1`
        for j in `seq 0 $rcount`; do
            rname=`echo $routes | jq ".[(${j})].name" | tr -d '"'`
            adpr=`echo $routes | jq ".[(${j})].addressPrefix" | tr -d '"'`
            nhtype=`echo $routes | jq ".[(${j})].nextHopType" | tr -d '"'`
            nhaddr=`echo $routes | jq ".[(${j})].nextHopIpAddress" | tr -d '"'`
            printf "\t route { \n" >> $prefix-$name.tf
            printf "\t\t name = \"%s\" \n" $rname >> $prefix-$name.tf
            printf "\t\t address_prefix = \"%s\" \n" $adpr >> $prefix-$name.tf
            printf "\t\t next_hop_type = \"%s\" \n" $nhtype >> $prefix-$name.tf
            if [ "$nhaddr" != "null" ]; then
                printf "\t\t next_hop_in_ip_address = \"%s\" \n" $nhaddr >> $prefix-$name.tf
            fi 
            printf "\t } \n" >> $prefix-$name.tf
        done
    fi
            #
        # Tags block
        #
        tags=`echo $azr | jq ".[(${i})].tags"`
        tcount=`echo $tags | jq '. | length'`
        #echo $tcount
        if [ "$tcount" -gt "0" ]; then
            printf "\t tags { \n" >> $prefix-$name.tf
            tt=`echo $tags | jq .`
            for j in `seq 1 $tcount`; do
                atag=`echo $tt | cut -d',' -f$j | tr -d '{' | tr -d '}'`
                tkey=`echo $atag | cut -d':' -f1 | tr -d '"'`
                tval=`echo $atag | cut -d':' -f2`
                printf "\t\t%s = %s \n" $tkey $tval >> $prefix-$name.tf
                
            done
            printf "\t}\n" >> $prefix-$name.tf
        fi



    #
    printf "}\n" >> $prefix-$name.tf
    #
    cat $prefix-$name.tf
    statecomm=`printf "terraform state rm %s.%s__%s" $tfp $rg $name`
    eval $statecomm
    evalcomm=`printf "terraform import %s.%s__%s %s" $tfp $rg $name $id`
    eval $evalcomm
    
done
fi
