project(
  'prismo',
  'cpp',
  version: '1.0.0',
  default_options: [
    'warning_level=3',
    'cpp_std=c++20',
    'optimization=0',
    'debug=true'
  ]
)

spdk_root = '/home/digo/Desktop/spdk'

project_inc = include_directories('include')
spdk_inc = include_directories(
  join_paths(spdk_root, 'include'),
  join_paths(spdk_root, 'build/include'),
  is_system: true
)

inc = [project_inc, spdk_inc]

# Define source files
src = files(
'src/main.cpp',
'src/engine/aio.cpp',
'src/engine/posix.cpp',
'src/engine/spdk.cpp',
'src/engine/uring.cpp',
'src/engine/utils.cpp',
'src/generator/content/deduplication.cpp',
'src/logger/spdlog.cpp',
'src/parser/parser.cpp',
'src/main.cpp',
)

cc = meson.get_compiler('cpp')

json_dep = dependency('nlohmann_json', required: true)
spdlog_dep = dependency('spdlog', required: true)
liburing_dep = dependency('liburing', required: true)
boost_dep = dependency( 'boost', modules: ['pool'], required: true)
libaio_dep = cc.find_library('aio', required: true)

spdk_env_dpdk_dep   = dependency('spdk_env_dpdk', required: true, static: true)
spdk_event_dep      = dependency('spdk_event', required: true, static: true)
spdk_bdev_dep       = dependency('spdk_bdev', required: true, static: true)
spdk_syslibs_dep    = dependency('spdk_syslibs', required: true, static: true)
spdk_conf_dep       = dependency('spdk_conf', required: true, static: true)
# spdk_event_bdev_dep = dependency('spdk_event_bdev', required: true, static: true)
# spdk_thread_dep     = dependency('spdk_thread', required: true, static: true)
# spdk_trace_dep      = dependency('spdk_trace', required: true, static: true)
# spdk_json_dep       = dependency('spdk_json', required: true, static: true)
# spdk_util_dep       = dependency('spdk_util', required: true, static: true)
# spdk_rpc_dep        = dependency('spdk_rpc', required: true, static: true)
# spdk_sock_dep       = dependency('spdk_sock', required: true, static: true)

# Find dpsk statib libraries
dpdk_libs = [
  join_paths(spdk_root, 'dpdk/build/lib/librte_mempool_ring.a'),
  # join_paths(spdk_root, 'dpdk/build/lib/librte_bus_pci.a'),
  # join_paths(spdk_root, 'dpdk/build/lib/librte_bus_vdev.a'),
  # join_paths(spdk_root, 'dpdk/build/lib/librte_cmdline.a'),
  # join_paths(spdk_root, 'dpdk/build/lib/librte_compressdev.a'),
  # join_paths(spdk_root, 'dpdk/build/lib/librte_cryptodev.a'),
  # join_paths(spdk_root, 'dpdk/build/lib/librte_dmadev.a'),
  # join_paths(spdk_root, 'dpdk/build/lib/librte_eal.a'),
  # join_paths(spdk_root, 'dpdk/build/lib/librte_ethdev.a'),
  # join_paths(spdk_root, 'dpdk/build/lib/librte_hash.a'),
  # join_paths(spdk_root, 'dpdk/build/lib/librte_kvargs.a'),
  # join_paths(spdk_root, 'dpdk/build/lib/librte_log.a'),
  # join_paths(spdk_root, 'dpdk/build/lib/librte_mbuf.a'),
  # join_paths(spdk_root, 'dpdk/build/lib/librte_mempool.a'),
  # join_paths(spdk_root, 'dpdk/build/lib/librte_meter.a'),
  # join_paths(spdk_root, 'dpdk/build/lib/librte_net.a'),
  # join_paths(spdk_root, 'dpdk/build/lib/librte_pci.a'),
  # join_paths(spdk_root, 'dpdk/build/lib/librte_power.a'),
  # join_paths(spdk_root, 'dpdk/build/lib/librte_power_acpi.a'),
  # join_paths(spdk_root, 'dpdk/build/lib/librte_power_amd_pstate.a'),
  # join_paths(spdk_root, 'dpdk/build/lib/librte_power_cppc.a'),
  # join_paths(spdk_root, 'dpdk/build/lib/librte_power_intel_pstate.a'),
  # join_paths(spdk_root, 'dpdk/build/lib/librte_power_intel_uncore.a'),
  # join_paths(spdk_root, 'dpdk/build/lib/librte_power_kvm_vm.a'),
  # join_paths(spdk_root, 'dpdk/build/lib/librte_rcu.a'),
  # join_paths(spdk_root, 'dpdk/build/lib/librte_reorder.a'),
  # join_paths(spdk_root, 'dpdk/build/lib/librte_ring.a'),
  # join_paths(spdk_root, 'dpdk/build/lib/librte_security.a'),
  # join_paths(spdk_root, 'dpdk/build/lib/librte_telemetry.a'),
  # join_paths(spdk_root, 'dpdk/build/lib/librte_timer.a'),
  # join_paths(spdk_root, 'dpdk/build/lib/librte_vhost.a'),
]

# Find spdk static libraries
spdk_libs = [
  join_paths(spdk_root, 'build/lib/libspdk_accel.a'),
  join_paths(spdk_root, 'build/lib/libspdk_bdev_malloc.a'),
  join_paths(spdk_root, 'build/lib/libspdk_event_accel.a'),
  join_paths(spdk_root, 'build/lib/libspdk_event_bdev.a'),
  join_paths(spdk_root, 'build/lib/libspdk_event_iobuf.a'),
  join_paths(spdk_root, 'build/lib/libspdk_event_keyring.a'),
  join_paths(spdk_root, 'build/lib/libspdk_event_scsi.a'),
  join_paths(spdk_root, 'build/lib/libspdk_event_sock.a'),
  join_paths(spdk_root, 'build/lib/libspdk_event_vmd.a'),
  join_paths(spdk_root, 'build/lib/libspdk_fsdev.a'),
  join_paths(spdk_root, 'build/lib/libspdk_iscsi.a'),
  join_paths(spdk_root, 'build/lib/libspdk_nbd.a'),
  join_paths(spdk_root, 'build/lib/libspdk_scsi.a'),
  join_paths(spdk_root, 'build/lib/libspdk_vhost.a'),
  join_paths(spdk_root, 'build/lib/libspdk_nvmf.a'),
  # join_paths(spdk_root, 'build/lib/libspdk_accel_error.a'),
  # join_paths(spdk_root, 'build/lib/libspdk_accel_ioat.a'),
  # join_paths(spdk_root, 'build/lib/libspdk_bdev.a'),
  # join_paths(spdk_root, 'build/lib/libspdk_bdev_aio.a'),
  # join_paths(spdk_root, 'build/lib/libspdk_bdev_delay.a'),
  # join_paths(spdk_root, 'build/lib/libspdk_bdev_error.a'),
  # join_paths(spdk_root, 'build/lib/libspdk_bdev_ftl.a'),
  # join_paths(spdk_root, 'build/lib/libspdk_bdev_gpt.a'),
  # join_paths(spdk_root, 'build/lib/libspdk_bdev_lvol.a'),
  # join_paths(spdk_root, 'build/lib/libspdk_bdev_null.a'),
  # join_paths(spdk_root, 'build/lib/libspdk_bdev_nvme.a'),
  # join_paths(spdk_root, 'build/lib/libspdk_bdev_passthru.a'),
  # join_paths(spdk_root, 'build/lib/libspdk_bdev_raid.a'),
  # join_paths(spdk_root, 'build/lib/libspdk_bdev_split.a'),
  # join_paths(spdk_root, 'build/lib/libspdk_bdev_virtio.a'),
  # join_paths(spdk_root, 'build/lib/libspdk_bdev_zone_block.a'),
  # join_paths(spdk_root, 'build/lib/libspdk_blob.a'),
  # join_paths(spdk_root, 'build/lib/libspdk_blob_bdev.a'),
  # join_paths(spdk_root, 'build/lib/libspdk_conf.a'),
  # join_paths(spdk_root, 'build/lib/libspdk_dma.a'),
  # join_paths(spdk_root, 'build/lib/libspdk_env_dpdk.a'),
  # join_paths(spdk_root, 'build/lib/libspdk_env_dpdk_rpc.a'),
  # join_paths(spdk_root, 'build/lib/libspdk_event.a'),
  # join_paths(spdk_root, 'build/lib/libspdk_event_fsdev.a'),
  # join_paths(spdk_root, 'build/lib/libspdk_event_iscsi.a'),
  # join_paths(spdk_root, 'build/lib/libspdk_event_nbd.a'),
  # join_paths(spdk_root, 'build/lib/libspdk_event_nvmf.a'),
  # join_paths(spdk_root, 'build/lib/libspdk_event_scheduler.a'),
  # join_paths(spdk_root, 'build/lib/libspdk_event_vhost_blk.a'),
  # join_paths(spdk_root, 'build/lib/libspdk_event_vhost_scsi.a'),
  # join_paths(spdk_root, 'build/lib/libspdk_fsdev_aio.a'),
  # join_paths(spdk_root, 'build/lib/libspdk_ftl.a'),
  # join_paths(spdk_root, 'build/lib/libspdk_fuse_dispatcher.a'),
  # join_paths(spdk_root, 'build/lib/libspdk_init.a'),
  # join_paths(spdk_root, 'build/lib/libspdk_ioat.a'),
  # join_paths(spdk_root, 'build/lib/libspdk_json.a'),
  # join_paths(spdk_root, 'build/lib/libspdk_jsonrpc.a'),
  # join_paths(spdk_root, 'build/lib/libspdk_keyring.a'),
  # join_paths(spdk_root, 'build/lib/libspdk_keyring_file.a'),
  # join_paths(spdk_root, 'build/lib/libspdk_keyring_linux.a'),
  # join_paths(spdk_root, 'build/lib/libspdk_log.a'),
  # join_paths(spdk_root, 'build/lib/libspdk_lvol.a'),
  # join_paths(spdk_root, 'build/lib/libspdk_notify.a'),
  # join_paths(spdk_root, 'build/lib/libspdk_nvme.a'),
  # join_paths(spdk_root, 'build/lib/libspdk_rpc.a'),
  # join_paths(spdk_root, 'build/lib/libspdk_scheduler_dpdk_governor.a'),
  # join_paths(spdk_root, 'build/lib/libspdk_scheduler_dynamic.a'),
  # join_paths(spdk_root, 'build/lib/libspdk_scheduler_gscheduler.a'),
  # join_paths(spdk_root, 'build/lib/libspdk_sock.a'),
  # join_paths(spdk_root, 'build/lib/libspdk_sock_posix.a'),
  # join_paths(spdk_root, 'build/lib/libspdk_thread.a'),
  # join_paths(spdk_root, 'build/lib/libspdk_trace.a'),
  # join_paths(spdk_root, 'build/lib/libspdk_trace_parser.a'),
  # join_paths(spdk_root, 'build/lib/libspdk_util.a'),
  # join_paths(spdk_root, 'build/lib/libspdk_vfio_user.a'),
  # join_paths(spdk_root, 'build/lib/libspdk_virtio.a'),
]

# Common flags for all builds
common_flags = [
  '-Wpedantic',
  '-Wshadow',
  '-Wnon-virtual-dtor',
]

# Compiler-specific flags
if cc.get_id() == 'gcc' or cc.get_id() == 'clang'
  extra_flags = [
    '-Wconversion',
    '-Wsign-conversion',
  ]
endif


# Compile the trace-parser tool
subdir('tools/trace-parser')

# add_project_arguments(common_flags + extra_flags, language: 'cpp')

prismo = executable(
  'prismo',
  sources: src,
  include_directories : inc,
  dependencies: [
    json_dep,
    spdlog_dep,
    liburing_dep,
    libaio_dep,
    boost_dep,
    spdk_bdev_dep,
    spdk_event_dep,
    spdk_conf_dep,
    spdk_env_dpdk_dep,
    spdk_syslibs_dep,
  ],
  link_args: [
    '-Wl,--whole-archive',
    dpdk_libs,
    spdk_libs,
    '-Wl,--no-whole-archive',
    '-fsanitize=address',
    '-fno-omit-frame-pointer',
    '-latomic',
  ],
  install : true,
)

test(
  'prismo_basic_test',
  prismo,
  args : ['-c', '../workloads/config.json']
)