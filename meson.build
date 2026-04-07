project(
    'prismo',
    'cpp',
    version: '1.0.0',
    default_options: [
        'warning_level=3',
        'cpp_std=c++20',
        'optimization=0',
        'debug=true',
    ],
)

spdk_root = meson.get_external_property('spdk_root')

project_inc = include_directories('include')
spdk_inc = include_directories(
    join_paths(spdk_root, 'include'),
    join_paths(spdk_root, 'build/include'),
    is_system: true,
)

src = files(
    'src/engine/aio.cpp',
    'src/engine/config.cpp',
    'src/engine/engine.cpp',
    'src/engine/posix.cpp',
    'src/engine/spdk.cpp',
    'src/engine/uring.cpp',
    'src/factory/factory.cpp',
    'src/generator/access/generator.cpp',
    'src/generator/content/compression.cpp',
    'src/generator/content/deduplication.cpp',
    'src/generator/content/generator.cpp',
    'src/generator/operation/barrier.cpp',
    'src/generator/operation/generator.cpp',
    'src/generator/tracebased/extension.cpp',
    'src/generator/tracebased/tracebased.cpp',
    'src/generator/tracebased/tracereader.cpp',
    'src/logger/spdlog.cpp',
    'src/main.cpp',
    'src/metric/statistics.cpp',
    'src/worker/consumer.cpp',
    'src/worker/job_manager.cpp',
    'src/worker/producer.cpp',
)

cc = meson.get_compiler('cpp')

libaio_dep = cc.find_library('aio', required: true)
spdlog_dep = dependency('spdlog', required: true)
eigen_dep = dependency('eigen3', required: true)
argparse_dep = dependency('argparse', required: true)
liburing_dep = dependency('liburing', required: true).as_system()
json_dep = dependency('nlohmann_json', required: true)
boost_dep = dependency('boost', modules: ['pool'], required: true)

spdk_env_dpdk_dep = dependency('spdk_env_dpdk', required: true, static: true)
spdk_event_dep = dependency('spdk_event', required: true, static: true)
spdk_bdev_dep = dependency('spdk_bdev', required: true, static: true)
spdk_syslibs_dep = dependency('spdk_syslibs', required: true, static: true)
spdk_conf_dep = dependency('spdk_conf', required: true, static: true)
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
]

# Common flags for all builds
common_flags = [
    '-Wpedantic',
    '-Wshadow',
    '-Wnon-virtual-dtor',
    '-Wconversion',
    '-Wsign-conversion',
]

# add_project_arguments(common_flags, language: 'cpp')

subdir('tools/astroide')
subdir('tools/deltoide')

prismo = executable(
    'prismo',
    sources: src,
    include_directories: [
        project_inc,
        spdk_inc,
    ],
    dependencies: [
        json_dep,
        eigen_dep,
        spdlog_dep,
        argparse_dep,
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
    install: true,
)

test(
    'prismo_basic_test',
    prismo,
    args: ['-c', '/home/digo/Desktop/prismo/workloads/config.json'],
)