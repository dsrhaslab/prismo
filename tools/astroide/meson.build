zstd_dep = dependency('libzstd', required: true)

executable(
  'astroide',
  sources: ['main.cpp'],
  include_directories: inc,
  dependencies: zstd_dep,
  cpp_args: common_flags,
  install: false
)
