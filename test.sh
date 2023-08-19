VOL_ID(){
	[ "$2" = "" ] && return
	local voluuid=""
	local voltype=""
	for i in `blkid $2`; do
	[ "${i#UUID=\"}" != "$i" ] && voluuid="${i#UUID=\"}" && voluuid="${voluuid%\"}"
	[ "${i#TYPE=\"}" != "$i" ] && voltype="${i#TYPE=\"}" && voltype="${voltype%\"}"
	done
	[ "$1" = "--uuid" ] && echo $voluuid
	[ "$1" = "--type" ] && echo $voltype
}

VOL_ID $*