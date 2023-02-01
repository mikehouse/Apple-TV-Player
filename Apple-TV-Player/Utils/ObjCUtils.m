//
//  ObjCUtils.m
//  Apple-TV-Player
//
//  Created by Mikhail Demidov on 31.12.2022.
//

#import <Foundation/Foundation.h>
#import "ObjCUtils.h"
#import <mach/mach.h>

@implementation ObjCUtilsMemStat

@end

@implementation ObjCUtils

// https://stackoverflow.com/a/8540665/3614746
+ (ObjCUtilsMemStat *)memStats {
    mach_port_t host_port;
    mach_msg_type_number_t host_size;
    vm_size_t pagesize;

    host_port = mach_host_self();
    host_size = sizeof(vm_statistics_data_t) / sizeof(integer_t);
    host_page_size(host_port, &pagesize);

    vm_statistics_data_t vm_stat;

    if (host_statistics(host_port, HOST_VM_INFO, (host_info_t)&vm_stat, &host_size) != KERN_SUCCESS) {
        return nil;
    }

    /* Stats in bytes */
    vm_size_t mem_used = (vm_stat.active_count +
                          vm_stat.inactive_count +
                          vm_stat.wire_count) * pagesize;
    vm_size_t mem_free = vm_stat.free_count * pagesize;
    vm_size_t mem_total = mem_used + mem_free;
    
    ObjCUtilsMemStat *stat = [[ObjCUtilsMemStat alloc] init];
    stat.usedMem = mem_used;
    stat.freeMem = mem_free;
    stat.totalMem = mem_total;
    return stat;
}

+ (double)cpuUsage {
    thread_array_t threads;
    mach_msg_type_number_t threadCount;
    if (task_threads(mach_task_self(), &threads, &threadCount) != KERN_SUCCESS) {
        return -1;
    }
    double usage = 0;
    for (int i = 0; i < threadCount; i++) {
        thread_info_data_t threadInfo;
        mach_msg_type_number_t threadInfoCount = THREAD_INFO_MAX;
        if (thread_info(threads[i], THREAD_BASIC_INFO, (thread_info_t) threadInfo, &threadInfoCount) != KERN_SUCCESS) {
            usage = -1;
            break;
        }
        thread_basic_info_t info = (thread_basic_info_t) threadInfo;
        if ((info->flags & TH_FLAGS_IDLE) == 0) {
            usage += ((double) info->cpu_usage) / TH_USAGE_SCALE;
        }
    }
    vm_deallocate(mach_task_self(), (vm_offset_t) threads, threadCount * sizeof(thread_t));
    return usage;
}

@end
