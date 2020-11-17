REPLACE_EXAMPLE="
/system/app/Youtube
/system/priv-app/SystemUI
/system/priv-app/Settings
/system/framework
"

# Construct your own list here
REPLACE="
"
ui_print "Mega Audio Mod by @maitreya29"
set_perm_recursive $MODPATH 0 0 0755 0644

set_permissions() {
  chown 0.2000 $MODPATH/system/vendor $MODPATH/system/vendor/etc $MODPATH/system/vendor/etc/dts $MODPATH/system/vendor/etc/dts/acc $MODPATH/system/vendor/lib $MODPATH/system/vendor/lib/soundfx $MODPATH/system/vendor/lib64 $MODPATH/system/vendor/lib64/soundfx
  chcon -R u:object_r:vendor_file:s0 $MODPATH/system/vendor
  chcon -R u:object_r:vendor_configs_file:s0 $MODPATH/system/vendor/etc
}

##########################################################################################
# MMT Extended Logic - Don't modify anything after this
##########################################################################################

SKIPUNZIP=1
unzip -qjo "$ZIPFILE" 'common/functions.sh' -d $TMPDIR >&2
. $TMPDIR/functions.sh
# Escape each backslash and space since shell will expand it during echo
sed -i -e 's/\\/\\\\/g' -e 's/\ /\\ /g' $MODPATH/AudioModificationLibrary.sh
# Separate AML into individual files for each audio mod
mkdir $MODPATH/.scripts
while read line; do
  case $line in
    \#*) if [ "$uuid" ]; then
           echo " " >> $MODPATH/.scripts/$uuid.sh
         fi
         uuid=$(echo "$line" | sed "s/#//");;
    *) echo "$line" >> $MODPATH/.scripts/$uuid.sh;;
  esac
done < $MODPATH/AudioModificationLibrary.sh
rm -f $MODPATH/AudioModificationLibrary.sh
# Generate libs var for faster script running
for i in $MODPATH/.scripts/*; do
  libs="$libs-name \"$(basename $i | sed "s/~.*//")\" "
done
libs="$(echo $libs | sed "s/\" /\" -o /g")"
sed -i -e "s|<libs>|$libs|" $MODPATH/service.sh

# Set vars in script
amldir=$NVBASE/aml
moddir=$NVBASE/modules
for i in API amldir moddir; do
  for j in post-fs-data service uninstall; do
    sed -i "s|$i=|$i=$(eval echo \$$i)|" $MODPATH/$j.sh
  done
done

# Place fallback script in the event idiot user deletes aml module in file explorer
cp -f $MODPATH/uninstall.sh $SERVICED/aml.sh && chmod 0755 $SERVICED/aml.sh
sed -i "3a[ -d \"\$moddir/$MODID\" ] && exit 0" $SERVICED/aml.sh
echo 'rm -f $0' >> $SERVICED/aml.sh
