project(
    'trace_parser',
    'cpp',
    version: '1.0.0',
    default_options: [
        'warning_level=3',
        'cpp_std=c++20',
        'optimization=0',
        'debug=true'
    ],
)

common_flags = [
    '-Wpedantic',
    '-Wshadow',
    '-Wnon-virtual-dtor',
    '-Wconversion',
    '-Wsign-conversion',
]

executable(
  'trace_parser',
  sources: ['main.cpp'],
  install: false
)
