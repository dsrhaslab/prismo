deltoide_inc = include_directories('include')
zstd_dep = dependency('libzstd', required: true)

executable(
  'deltoide',
  sources: ['src/main.cpp'],
  include_directories: inc + deltoide_inc,
  dependencies: zstd_dep,
  cpp_args: common_flags,
  install: false
)
