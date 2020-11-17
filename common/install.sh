ui_print "Installing DTS-X"
osp_detect() {
  case $1 in
    *.conf) SPACES=$(sed -n "/^output_session_processing {/,/^}/ {/^ *music {/p}" $1 | sed -r "s/( *).*/\1/")
            EFFECTS=$(sed -n "/^output_session_processing {/,/^}/ {/^$SPACES\music {/,/^$SPACES}/p}" $1 | grep -E "^$SPACES +[A-Za-z]+" | sed -r "s/( *.*) .*/\1/g")
            for EFFECT in ${EFFECTS}; do
              SPACES=$(sed -n "/^effects {/,/^}/ {/^ *$EFFECT {/p}" $1 | sed -r "s/( *).*/\1/")
              [ "$EFFECT" != "atmos" -a "$EFFECT" != "dtsaudio" ] && sed -i "/^effects {/,/^}/ {/^$SPACES$EFFECT {/,/^$SPACES}/d}" $1
            done;;
    *.xml) EFFECTS=$(sed -n "/^ *<postprocess>$/,/^ *<\/postprocess>$/ {/^ *<stream type=\"music\">$/,/^ *<\/stream>$/ {/<stream type=\"music\">/d; /<\/stream>/d; s/<apply effect=\"//g; s/\"\/>//g; s/ *//g; p}}" $1)
            for EFFECT in ${EFFECTS}; do
              [ "$EFFECT" != "atmos" -a "$EFFECT" != "dtsaudio" ] && sed -i "/^\( *\)<apply effect=\"$EFFECT\"\/>/d" $1
            done;;
  esac
}

processing_patch() {
  if [ "$1" == "pre" ]; then
    CONF=pre_processing
    XML=preprocess
  elif [ "$1" == "post" ]; then
    CONF=output_session_processing
    XML=postprocess
  fi
  case $2 in
    *.conf) if [ ! "$(sed -n "/^$CONF {/,/^}/p" $2)" ]; then
              echo -e "\n$CONF {\n    $3 {\n        $4 {\n        }\n    }\n}" >> $2
            elif [ ! "$(sed -n "/^$CONF {/,/^}/ {/$3 {/,/^    }/p}" $2)" ]; then
              sed -i "/^$CONF {/,/^}/ s/$CONF {/$CONF {\n    $3 {\n        $4 {\n        }\n    }/" $2
            elif [ ! "$(sed -n "/^$CONF {/,/^}/ {/$3 {/,/^    }/ {/$4 {/,/}/p}}" $2)" ]; then
              sed -i "/^$CONF {/,/^}/ {/$3 {/,/^    }/ s/$3 {/$3 {\n        $4 {\n        }/}" $2
            fi;;
    *.xml) if [ ! "$(sed -n "/^ *<$XML>/,/^ *<\/$XML>/p" $2)" ]; then     
             sed -i "/<\/audio_effects_conf>/i\    <$XML>\n       <stream type=\"$3\">\n            <apply effect=\"$4\"\/>\n        <\/stream>\n    <\/$XML>" $2
           elif [ ! "$(sed -n "/^ *<$XML>/,/^ *<\/$XML>/ {/<stream type=\"$3\">/,/<\/stream>/p}" $2)" ]; then     
             sed -i "/^ *<$XML>/,/^ *<\/$XML>/ s/    <$XML>/    <$XML>\n        <stream type=\"$3\">\n            <apply effect=\"$4\"\/>\n        <\/stream>/" $2
           elif [ ! "$(sed -n "/^ *<$XML>/,/^ *<\/$XML>/ {/<stream type=\"$3\">/,/<\/stream>/ {/^ *<apply effect=\"$4\"\/>/p}}" $2)" ]; then
             sed -i "/^ *<$XML>/,/^ *<\/$XML>/ {/<stream type=\"$3\">/,/<\/stream>/ s/<stream type=\"$3\">/<stream type=\"$3\">\n            <apply effect=\"$4\"\/>/}" $2
           fi;;
  esac
}

[ -f /system/vendor/build.prop ] && BUILDS="/system/build.prop /system/vendor/build.prop" || BUILDS="/system/build.prop"
CFGS="$(find /system /vendor -type f -name "*audio_effects*.conf" -o -name "*audio_effects*.xml")"
VNDK=$(find /system/lib /vendor/lib -type d -iname "*vndk*")
VNDK64=$(find /system/lib64 /vendor/lib64 -type d -iname "*vndk*")
M9=$(grep -E "ro.aa.modelid=0PJA.*|ro.product.device=himaul*" $BUILDS)

# Tell user aml is needed if applicable
FILES=$(find $NVBASE/modules/*/system $MODULEROOT/*/system -type f -name "*audio_effects*.conf" -o -name "*audio_effects*.xml" 2>/dev/null)
if [ ! -z "$FILES" ] && [ ! "$(echo $FILES | grep '/aml/')" ]; then
  ui_print " "
  ui_print "   ! Conflicting audio mod found!"
  ui_print "   ! You will need to install !"
  ui_print "   ! Audio Modification Library !"
  sleep 3
fi

[ -d $NVBASE/modules/DTS_HPX ] && touch $NVBASE/modules/DTS_HPX/remove
[ "$M9" ] && rm -f $MODPATH/service.sh

ui_print " "
ui_print " "
ui_print "   ! This port might require !"
ui_print "   ! PERMISSIVE SELINUX !"
ui_print "   ! On some devices & OEM Roms !"
ui_print " "
ui_print " "
sleep 2

ui_print " "
ui_print "   Removing remnants from past DTS:X installs..."
# Uninstall previous DTS:X installs
DTSAPPS=$(find /data/app -type d -name "*com.dts.dtsxultra*")
if [ "$DTSAPPS" ]; then
  for APP in ${DTSAPPS}; do
    case $APP in
      *com.dts.dtsxultra*) pm uninstall com.dts.dtsxultra >/dev/null 2>&1;;
    esac
  done
fi

# Get old/new from zip name
OIFS=$IFS; IFS=\|
case $(echo $(basename $ZIPFILE) | tr '[:upper:]' '[:lower:]') in
  *ray*) VIVO=true;;
  *void*) VIVO=false;;
esac

# Get lib workaround from zip name
case $(echo $(basename $ZIPFILE) | tr '[:upper:]' '[:lower:]') in
  *lib*) LIBWA=true;;
  *nlib*) LIBWA=false;;
esac
IFS=$OIFS

ui_print " "
if [ -z $VIVO ] || [ -z $LIBWA ]; then
  if [ -z $VIVO ]; then
  	ui_print "Installing DTS-X"
    ui_print " "
    ui_print " - Preset Options -"
    ui_print "   Which Presets would you want to enable?"
    ui_print "   * RAY for overall crisper tune"
    ui_print "   * VOID for deepen punchy tune"
    ui_print " "
    sleep 2
    ui_print "   Vol Up = RAY, Vol Down = VOID"
    ui_print " "
    if $VKSEL; then
      VIVO=true
	  ui_print "   Embrace the RAY"
    else
      VIVO=false
      ui_print "   Enter the VOID"
    fi
    if [ -z $LIBWA ]; then
      ui_print " "
      ui_print " - Use lib workaround? -"
      ui_print "   * Might help resolving delay issues"
      ui_print " "
      sleep 2
      ui_print "   Vol+ = yes, Vol- = no (recommended)"
      ui_print " "
      if $VKSEL; then
        LIBWA=true
      else
        LIBWA=false
      fi
    else
      ui_print "   Lib workaround option specified in zipname!"
    fi
  else
    ui_print "   Preset option specified in zipname!"
  fi
else
  ui_print "   Options specified in zip name!"
fi

tar -xf $MODPATH/common/custom.tar.xz -C $MODPATH/common 2>/dev/null
if $VIVO; then
  cp_ch -r $MODPATH/common/custom/ray/dts $MODPATH/system/vendor/etc
else
  cp_ch -r $MODPATH/common/custom/void/dts $MODPATH/system/vendor/etc
fi

mkdir -p /data/vendor/audio/dts
mkdir -p /data/misc/dts

if $LIBWA; then
  ui_print "   Applying lib workaround..."
  if [ -f $ORIGDIR/system/lib/libstdc++.so ] && [ ! -f $ORIGDIR/vendor/lib/libstdc++.so ]; then
    cp_ch $ORIGDIR/system/lib/libstdc++.so $MODPATH/system/vendor/lib/libstdc++.so
  elif [ -f $ORIGDIR/vendor/lib/libstdc++.so ] && [ ! -f $ORIGDIR/system/lib/libstdc++.so ]; then
    cp_ch $ORIGDIR/vendor/lib/libstdc++.so $MODPATH/system/lib/libstdc++.so
  fi
fi

ui_print "   Patching existing audio_effects files..."
for OFILE in ${CFGS}; do
  FILE="$MODPATH$(echo $OFILE | sed "s|^/vendor|/system/vendor|g")"
  cp_ch -n $ORIGDIR$OFILE $FILE
  osp_detect $FILE
  case $FILE in
    *.conf) sed -i "/dtsaudio {/,/}/d" $FILE
            sed -i "s/^libraries {/libraries {\n  dtsaudio { #$MODID\n    path $LIBPATCH\/lib\/soundfx\/libdtsaudio.so\n  } #$MODID/g" $FILE
            sed -i "s/^effects {/effects {\n  dtsaudio { #$MODID\n    library dtsaudio\n    uuid 146edfc0-7ed2-11e4-80eb-0002a5d5c51b\n  } #$MODID/g" $FILE
            processing_patch "post" "$FILE" "music" "dtsaudio";;
   *.xml) sed -i "/dtsaudio/d" $FILE
          sed -i "/<libraries>/ a\        <library name=\"dtsaudio\" path=\"libdtsaudio.so\"\/><!--$MODID-->" $FILE
          sed -i "/<effects>/ a\        <effect name=\"dtsaudio\" library=\"dtsaudio\" uuid=\"146edfc0-7ed2-11e4-80eb-0002a5d5c51b\"\/><!--$MODID-->" $FILE
          processing_patch "post" "$FILE" "music" "dtsaudio";;
    esac
done
