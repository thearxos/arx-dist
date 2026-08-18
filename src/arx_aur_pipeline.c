/* ARX AUR bounded native verification pool. */
#include <pthread.h>
#include <stddef.h>
#include <stdlib.h>
#include <stdatomic.h>
typedef int (*arx_check_fn)(const char *path);
typedef struct { const char **paths; size_t count,next; arx_check_fn check; atomic_int failed; pthread_mutex_t lock; } arx_pool;
static void *worker(void *arg){ arx_pool *p=arg; for(;;){size_t i;pthread_mutex_lock(&p->lock);if(p->next>=p->count){pthread_mutex_unlock(&p->lock);break;}i=p->next++;pthread_mutex_unlock(&p->lock);if(p->check(p->paths[i])!=0)atomic_store(&p->failed,1);}return NULL;}
int arx_aur_parallel_check(const char **paths,size_t count,arx_check_fn check,unsigned threads){
 if(!paths||!check||!count)return 0;if(threads<1)threads=1;if(threads>count)threads=(unsigned)count;arx_pool p={paths,count,0,check,0,PTHREAD_MUTEX_INITIALIZER};pthread_t *ts=calloc(threads,sizeof(*ts));if(!ts)return -1;unsigned made=0;for(;made<threads;made++)if(pthread_create(&ts[made],NULL,worker,&p)!=0)break;for(unsigned i=0;i<made;i++)pthread_join(ts[i],NULL);free(ts);return atomic_load(&p.failed)?1:(made==threads?0:-1);
}
