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

@end
