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

vcpkg_include = meson.get_external_property('vcpkg_include')
dpdk_build_lib = meson.get_external_property('dpdk_build_lib')
spdk_build_lib = meson.get_external_property('spdk_build_lib')

project_inc = include_directories('include')
spdk_inc = include_directories(
	meson.get_external_property('spdk_include'),
	meson.get_external_property('spdk_build_include'),
	is_system: true,
)

src = files(
	'src/communication/channel.cpp',
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
	'src/logger/logger.cpp',
	'src/logger/spdlog.cpp',
	'src/main.cpp',
	'src/metric/statistics.cpp',
	'src/worker/consumer.cpp',
	'src/worker/job_manager.cpp',
	'src/worker/producer.cpp',
)

cc = meson.get_compiler('cpp')

libaio_dep = cc.find_library('aio',
	required: true,
)

spdlog_dep = dependency('spdlog',
	method: 'pkg-config',
	required: true,
)

eigen_dep = dependency('eigen3',
	method: 'pkg-config',
	required: true,
)

json_dep = dependency('nlohmann_json',
	method: 'pkg-config',
	required: true,
)

liburing_dep = dependency('liburing',
	method: 'pkg-config',
	required: true,
).as_system()

argparse_dep = declare_dependency(
	include_directories: include_directories(
		vcpkg_include,
		is_system: true,
	),
)

boost_dep = declare_dependency(
	include_directories: include_directories(
		vcpkg_include,
		is_system: true,
	),
)

spdk_env_dpdk_dep = dependency('spdk_env_dpdk',
	method: 'pkg-config',
	static: true,
	required: true,
)

spdk_event_dep = dependency('spdk_event',
	method: 'pkg-config',
	static: true,
	required: true,
)

spdk_bdev_dep = dependency('spdk_bdev',
	method: 'pkg-config',
	static: true,
	required: true,
)

spdk_syslibs_dep = dependency('spdk_syslibs',
	method: 'pkg-config',
	static: true,
	required: true,
)

spdk_conf_dep = dependency('spdk_conf',
	method: 'pkg-config',
	static: true,
	required: true,
)

# spdk_event_bdev_dep = dependency('spdk_event_bdev',
# 	required: true,
# 	static: true,
# )

# spdk_thread_dep = dependency('spdk_thread',
# 	required: true,
# 	static: true,
# )

# spdk_trace_dep = dependency('spdk_trace',
# 	required: true,
# 	static: true,
# )

# spdk_json_dep = dependency('spdk_json',
# 	required: true,
# 	static: true,
# )

# spdk_util_dep = dependency('spdk_util',
# 	required: true,
# 	static: true,
# )

# spdk_rpc_dep = dependency('spdk_rpc',
# 	required: true,
# 	static: true,
# )

# spdk_sock_dep = dependency('spdk_sock',
# 	required: true,
# 	static: true,
# )

dpdk_libs = [
	join_paths(dpdk_build_lib, 'librte_mempool_ring.a'),
]

spdk_libs = [
	join_paths(spdk_build_lib, 'libspdk_accel.a'),
	join_paths(spdk_build_lib, 'libspdk_bdev_malloc.a'),
	join_paths(spdk_build_lib, 'libspdk_event_accel.a'),
	join_paths(spdk_build_lib, 'libspdk_event_bdev.a'),
	join_paths(spdk_build_lib, 'libspdk_event_iobuf.a'),
	join_paths(spdk_build_lib, 'libspdk_event_keyring.a'),
	join_paths(spdk_build_lib, 'libspdk_event_scsi.a'),
	join_paths(spdk_build_lib, 'libspdk_event_sock.a'),
	join_paths(spdk_build_lib, 'libspdk_event_vmd.a'),
	join_paths(spdk_build_lib, 'libspdk_fsdev.a'),
	join_paths(spdk_build_lib, 'libspdk_iscsi.a'),
	join_paths(spdk_build_lib, 'libspdk_nbd.a'),
	join_paths(spdk_build_lib, 'libspdk_scsi.a'),
	join_paths(spdk_build_lib, 'libspdk_vhost.a'),
	join_paths(spdk_build_lib, 'libspdk_nvmf.a'),
]

common_flags = [
	'-Wpedantic',
	'-Wshadow',
	'-Wnon-virtual-dtor',
	'-Wconversion',
	'-Wsign-conversion',
]

# add_project_arguments(
# 	common_flags,
# 	language: 'cpp',
# )

subdir('tools/astroide')
subdir('tools/deltoide')

executable(
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