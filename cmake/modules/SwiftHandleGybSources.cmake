include(SwiftAddCustomCommandTarget)
include(SwiftSetIfArchBitness)

# Create a target to process single gyb source with the 'gyb' tool.
#
# handle_gyb_source_single(
#     dependency_out_var_name
#     SOURCE src_gyb
#     OUTPUT output
#     [FLAGS [flags ...]])
#     [DEPENDS [depends ...]]
#     [COMMENT comment])
#
# dependency_out_var_name
#   The name of a variable, to be set in the parent scope to be the target
#   target that invoke gyb.
#
# src_gyb
#   .gyb suffixed source file
#
# output
#   Output filename to be generated
#
# flags ...
#    gyb flags in addition to ${SWIFT_GYB_FLAGS}.
#
# depends ...
#    gyb flags in addition to 'src_gyb' and sources of gyb itself.
#
# comment
#    Additional comment.
function(handle_gyb_source_single dependency_out_var_name)
  set(options)
  set(single_value_args SOURCE OUTPUT COMMENT)
  set(multi_value_args FLAGS DEPENDS)
  cmake_parse_arguments(
      GYB_SINGLE # prefix
      "${options}" "${single_value_args}" "${multi_value_args}" ${ARGN})

  set(gyb_tool "${SWIFT_SOURCE_DIR}/utils/gyb")
  set(gyb_tool_source "${gyb_tool}" "${gyb_tool}.py")

  get_filename_component(dir "${GYB_SINGLE_OUTPUT}" DIRECTORY)
  get_filename_component(basename "${GYB_SINGLE_OUTPUT}" NAME)

  # Handle foo.gyb in pattern ``gyb.expand('foo.gyb'`` as a dependency
  set(gyb_expand_deps "")
  file(READ "${GYB_SINGLE_SOURCE}" gyb_file)
  string(REGEX MATCHALL "\\\$\{[\r\n\t ]*gyb.expand\\\([\r\n\t ]*[\'\"]([^\'\"]*)[\'\"]" gyb_expand_matches "${gyb_file}")
  foreach(match ${gyb_expand_matches})
    string(REGEX MATCH "[\'\"]\([^\'\"]*\)[\'\"]" gyb_dep "${match}")
    list(APPEND gyb_expand_deps "${CMAKE_MATCH_1}")
  endforeach()
  list(REMOVE_DUPLICATES gyb_expand_deps)

  set(SWIFT_SYNTAX_GYB_SUPPORT_DIR "${SWIFT_PATH_TO_SWIFT_SYNTAX_SOURCE}/Sources/generate-swift-syntax-builder")

  add_custom_command_target(
      dependency_target
      COMMAND
          "${CMAKE_COMMAND}" -E make_directory "${dir}"
      COMMAND
          "${CMAKE_COMMAND}" -E env PYTHONPATH=${SWIFT_SYNTAX_GYB_SUPPORT_DIR} "$<TARGET_FILE:Python3::Interpreter>" "${gyb_tool}" ${SWIFT_GYB_FLAGS} ${GYB_SINGLE_FLAGS} -o "${GYB_SINGLE_OUTPUT}.tmp" "${GYB_SINGLE_SOURCE}"
      COMMAND
          "${CMAKE_COMMAND}" -E copy_if_different "${GYB_SINGLE_OUTPUT}.tmp" "${GYB_SINGLE_OUTPUT}"
      COMMAND
          "${CMAKE_COMMAND}" -E remove "${GYB_SINGLE_OUTPUT}.tmp"
      OUTPUT "${GYB_SINGLE_OUTPUT}"
      DEPENDS "${gyb_tool_source}" "${GYB_SINGLE_DEPENDS}" "${GYB_SINGLE_SOURCE}" "${gyb_expand_deps}"
      COMMENT "Generating ${basename} from ${GYB_SINGLE_SOURCE} ${GYB_SINGLE_COMMENT}"
      WORKING_DIRECTORY "${CMAKE_CURRENT_SOURCE_DIR}"
      SOURCES "${GYB_SINGLE_SOURCE}"
      IDEMPOTENT)
  set("${dependency_out_var_name}" "${dependency_target}" PARENT_SCOPE)
endfunction()

# Create a target to process .gyb files with the 'gyb' tool.
#
# handle_gyb_sources(
#     dependency_out_var_name
#     sources_var_name
#     [ARCH arch]
#     [DEPENDS [depends ...]])
#
# Replace, in ${sources_var_name}, the given .gyb-suffixed sources with
# their un-suffixed intermediate files, which will be generated by processing
# the .gyb files with gyb.
#
# dependency_out_var_name
#   The name of a variable, to be set in the parent scope to the list of
#   targets that invoke gyb.  Every target that depends on the generated
#   sources should depend on ${dependency_out_var_name} targets.
#
# arch
#   The architecture that the files will be compiled for.  If this is
#   false, the files are architecture-independent and will be emitted
#   into ${CMAKE_CURRENT_BINARY_DIR} instead of an architecture-specific
#   destination; this is useful for generated include files.
#
# depends
#   Additional file dependencies beyond the standard dependencies that all gyb
#   invocations get.
function(handle_gyb_sources dependency_out_var_name sources_var_name)
  set(options)
  set(single_value_args ARCH)
  set(multi_value_args DEPENDS)
  cmake_parse_arguments(GYB
    "${options}" "${single_value_args}" "${multi_value_args}" ${ARGN})

  set(extra_gyb_flags "")
  if (GYB_ARCH)
    set_if_arch_bitness(ptr_size
      ARCH "${GYB_ARCH}"
      CASE_32_BIT "4"
      CASE_64_BIT "8")
    set(extra_gyb_flags "-DCMAKE_SIZEOF_VOID_P=${ptr_size}")
  endif()

  set(dependency_targets)
  set(de_gybbed_sources)
  set(gyb_extra_sources
      "${SWIFT_SOURCE_DIR}/utils/GYBUnicodeDataUtils.py"
      "${SWIFT_SOURCE_DIR}/utils/SwiftIntTypes.py"
      "${SWIFT_SOURCE_DIR}/utils/SwiftFloatingPointTypes.py"
      "${SWIFT_SOURCE_DIR}/utils/UnicodeData/GraphemeBreakProperty.txt"
      "${SWIFT_SOURCE_DIR}/utils/UnicodeData/GraphemeBreakTest.txt"
      "${SWIFT_SOURCE_DIR}/utils/gyb_stdlib_support.py"
      "${SWIFT_PATH_TO_SWIFT_SYNTAX_SOURCE}/Sources/generate-swift-syntax-builder/gyb_syntax_support/__init__.py"
      "${SWIFT_PATH_TO_SWIFT_SYNTAX_SOURCE}/Sources/generate-swift-syntax-builder/gyb_syntax_support/Child.py"
      "${SWIFT_PATH_TO_SWIFT_SYNTAX_SOURCE}/Sources/generate-swift-syntax-builder/gyb_syntax_support/Classification.py"
      "${SWIFT_PATH_TO_SWIFT_SYNTAX_SOURCE}/Sources/generate-swift-syntax-builder/gyb_syntax_support/kinds.py"
      "${SWIFT_PATH_TO_SWIFT_SYNTAX_SOURCE}/Sources/generate-swift-syntax-builder/gyb_syntax_support/Node.py"
      "${SWIFT_PATH_TO_SWIFT_SYNTAX_SOURCE}/Sources/generate-swift-syntax-builder/gyb_syntax_support/AttributeNodes.py"
      "${SWIFT_PATH_TO_SWIFT_SYNTAX_SOURCE}/Sources/generate-swift-syntax-builder/gyb_syntax_support/AvailabilityNodes.py"
      "${SWIFT_PATH_TO_SWIFT_SYNTAX_SOURCE}/Sources/generate-swift-syntax-builder/gyb_syntax_support/CommonNodes.py"
      "${SWIFT_PATH_TO_SWIFT_SYNTAX_SOURCE}/Sources/generate-swift-syntax-builder/gyb_syntax_support/DeclNodes.py"
      "${SWIFT_PATH_TO_SWIFT_SYNTAX_SOURCE}/Sources/generate-swift-syntax-builder/gyb_syntax_support/ExprNodes.py"
      "${SWIFT_PATH_TO_SWIFT_SYNTAX_SOURCE}/Sources/generate-swift-syntax-builder/gyb_syntax_support/GenericNodes.py"
      "${SWIFT_PATH_TO_SWIFT_SYNTAX_SOURCE}/Sources/generate-swift-syntax-builder/gyb_syntax_support/NodeSerializationCodes.py"
      "${SWIFT_PATH_TO_SWIFT_SYNTAX_SOURCE}/Sources/generate-swift-syntax-builder/gyb_syntax_support/PatternNodes.py"
      "${SWIFT_PATH_TO_SWIFT_SYNTAX_SOURCE}/Sources/generate-swift-syntax-builder/gyb_syntax_support/StmtNodes.py"
      "${SWIFT_PATH_TO_SWIFT_SYNTAX_SOURCE}/Sources/generate-swift-syntax-builder/gyb_syntax_support/TypeNodes.py"
      "${SWIFT_PATH_TO_SWIFT_SYNTAX_SOURCE}/Sources/generate-swift-syntax-builder/gyb_syntax_support/Token.py"
      "${SWIFT_PATH_TO_SWIFT_SYNTAX_SOURCE}/Sources/generate-swift-syntax-builder/gyb_syntax_support/Trivia.py"
      "${SWIFT_PATH_TO_SWIFT_SYNTAX_SOURCE}/Sources/generate-swift-syntax-builder/gyb_syntax_support/Traits.py"
      "${SWIFT_SOURCE_DIR}/utils/gyb_sourcekit_support/__init__.py"
      "${SWIFT_SOURCE_DIR}/utils/gyb_sourcekit_support/UIDs.py")

  foreach (src ${${sources_var_name}})
    # On Windows (using Visual Studio), the generated project files assume that the
    # generated GYB files will be in the source, not binary directory.
    # We can work around this by modifying the root directory when generating VS projects.
    if ("${CMAKE_GENERATOR_PLATFORM}" MATCHES "Visual Studio")
      set(dir_root ${CMAKE_CURRENT_SOURCE_DIR})
    else()
      set(dir_root ${CMAKE_CURRENT_BINARY_DIR})
    endif()

    if (GYB_ARCH)
      set(dir "${dir_root}/${ptr_size}")
    else()
      set(dir "${dir_root}")
    endif()
    # get_filename_component(src_sans_gyb ${src} NAME_WLE)
    string(REGEX REPLACE "\.gyb$" "" src_sans_gyb ${src})
    set(output_file_name "${dir}/${src_sans_gyb}")
    list(APPEND de_gybbed_sources "${output_file_name}")
    handle_gyb_source_single(dependency_target
        SOURCE "${src}"
        OUTPUT "${output_file_name}"
        FLAGS ${extra_gyb_flags}
        DEPENDS "${GYB_DEPENDS}" "${gyb_extra_sources}"
        COMMENT "with ptr size = ${ptr_size}")
    list(APPEND dependency_targets "${dependency_target}")
  endforeach()
  set("${dependency_out_var_name}" "${dependency_targets}" PARENT_SCOPE)
  set("${sources_var_name}" "${de_gybbed_sources}" PARENT_SCOPE)
endfunction()

function(add_gyb_target target sources)
  handle_gyb_sources(gyb_sources_depends sources ${ARGN})

  add_custom_target(${target}
    DEPENDS "${gyb_sources_depends}")
endfunction()
