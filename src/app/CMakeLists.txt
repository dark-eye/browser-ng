project(webbrowser-common)

find_package(Qt5Core REQUIRED)
find_package(Qt5Gui REQUIRED)
find_package(Qt5Network REQUIRED)
find_package(Qt5Qml REQUIRED)
find_package(Qt5Quick REQUIRED)
find_package(Qt5Widgets REQUIRED)
#find_package(Qt5WebEngine REQUIRED)

include(FindPkgConfig)

configure_file(
    config.h.in
    ${CMAKE_CURRENT_BINARY_DIR}/config.h
    @ONLY)

set(COMMONLIB webbrowser-common)

set(COMMONLIB_SRC
    browserapplication.cpp
    favicon-fetcher.cpp
    meminfo.cpp
    mime-database.cpp
    session-storage.cpp
    single-instance-manager.cpp
)

add_library(${COMMONLIB} STATIC ${COMMONLIB_SRC})

include_directories(${LIBAPPARMOR_INCLUDE_DIRS})
target_link_libraries(${COMMONLIB}
    Qt5::Core
    Qt5::Gui
    Qt5::Network
    Qt5::Qml
    Qt5::Quick
    Qt5::Widgets
    ${LIBAPPARMOR_LDFLAGS}
)

file(GLOB QML_FILES *.qml)
install(FILES ${QML_FILES} DESTINATION ${CMAKE_INSTALL_DATADIR}/webbrowser-ng)
file(GLOB JS_FILES *.js)
install(FILES ${JS_FILES} DESTINATION ${CMAKE_INSTALL_DATADIR}/webbrowser-ng)
install(DIRECTORY actions DESTINATION ${CMAKE_INSTALL_DATADIR}/webbrowser-ng
        FILES_MATCHING PATTERN *.qml)

add_subdirectory(webbrowser)
#add_subdirectory(webcontainer)
