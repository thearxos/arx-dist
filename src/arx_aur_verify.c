/* ARX AUR trust gate: reject verification bypasses and preserve native signature checks. */
#include <string.h>
int arx_aur_verify_args(const char *args){
 if(!args) return 0;
 if(strstr(args,"--skipinteg") || strstr(args,"--skippgpcheck")) return 4;
 return 0;
}
int arx_aur_verify_pkg(const char *path){
 if(!path || !*path) return 2;
 return 0;
}
