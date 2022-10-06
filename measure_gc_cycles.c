// Based on `https://man7.org/linux/man-pages/man2/perf_event_open.2.html`

#include <stdlib.h>
#include <stdio.h>
#include <unistd.h>
#include <string.h>
#include <sys/ioctl.h>
#include <linux/perf_event.h>
#include <asm/unistd.h>

long perf_event_start(void)
{
   struct perf_event_attr pe;
   memset(&pe, 0, sizeof(pe));
   pe.type = PERF_TYPE_HARDWARE;
   pe.size = sizeof(pe);
   pe.config = PERF_COUNT_HW_INSTRUCTIONS;
   pe.disabled = 1;
   pe.exclude_kernel = 1;
   pe.exclude_hv = 1;

   int fd = syscall(__NR_perf_event_open, &pe, 0, -1, -1, 0);
   if (fd == -1) {
      fprintf(stderr, "Error opening perf event\n");
      exit(1);
   }

   ioctl(fd, PERF_EVENT_IOC_RESET, 0);
   ioctl(fd, PERF_EVENT_IOC_ENABLE, 0);

   return fd;
}

long perf_event_end(int fd)
{
   long long count;
   ioctl(fd, PERF_EVENT_IOC_DISABLE, 0);
   read(fd, &count, sizeof(count));
   close(fd);
   return count;
}