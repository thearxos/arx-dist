/* ARX native AUR policy gate. Heavy scanners are invoked by the caller only after cheap checks. */
#include <string.h>
#include <stddef.h>
static int contains_any(const char *s,const char *const *v,size_t n){if(!s)return 0;for(size_t i=0;i<n;i++)if(strstr(s,v[i]))return 1;return 0;}
int arx_aur_policy_scan(const char *text){
 static const char *danger[]={"--skipinteg","--skippgpcheck","--noextract","curl | sh","wget | sh","curl|sh","wget|sh","/dev/tcp/","/dev/udp/","LD_PRELOAD=","authorized_keys","/etc/cron","systemctl enable","chmod +s","setcap ","eval $(curl","eval $(wget"};
 return contains_any(text,danger,sizeof(danger)/sizeof(danger[0])) ? 1 : 0;
}
