"""Generate the dependency-free, shared iOS/macOS Xcode project."""
from pathlib import Path
import hashlib
import sys
import json
root = Path(__file__).resolve().parent.parent
def emit(path, value):
    if '--check' in sys.argv:
        if not path.exists() or path.read_text() != value: raise SystemExit(f'Generated project is stale: {path.name}. Run python3 scripts/generate_project.py')
    else: path.write_text(value)
objects = []
def ident(name): return hashlib.sha1(name.encode()).hexdigest()[:24].upper()
def obj(name, value):
    key = ident(name)
    objects.append(f'{key} = {{ {value} }};')
    return key
def q(value): return json.dumps(str(value))
config_ref = obj('config_ref', 'isa = PBXFileReference; lastKnownFileType = text.xcconfig; path = Config/Capabilities.xcconfig; sourceTree = SOURCE_ROOT;')
refs, builds = [], []
for path in sorted((root / 'App').glob('*.swift')):
    ref = obj('ref:' + path.name, f'isa = PBXFileReference; lastKnownFileType = sourcecode.swift; path = {q(path.name)}; sourceTree = "<group>";')
    refs.append(ref)
    builds.append(obj('build:' + path.name, f'isa = PBXBuildFile; fileRef = {ref};'))
app_group = obj('app_group', 'isa = PBXGroup; children = (' + ','.join(refs) + '); path = App; sourceTree = "<group>";')
product = obj('app_product', 'isa = PBXFileReference; explicitFileType = wrapper.application; path = FORGE.app; sourceTree = BUILT_PRODUCTS_DIR;')
products = obj('products', f'isa = PBXGroup; children = ({product}); name = Products; sourceTree = "<group>";')
main = obj('main', f'isa = PBXGroup; children = ({app_group},{products},{config_ref}); sourceTree = "<group>";')
package = obj('package', 'isa = XCLocalSwiftPackageReference; relativePath = .;')
core = obj('core_product', f'isa = XCSwiftPackageProductDependency; package = {package}; productName = ForgeCore;')
framework = obj('core_build', f'isa = PBXBuildFile; productRef = {core};')
sources = obj('sources', 'isa = PBXSourcesBuildPhase; buildActionMask = 2147483647; files = (' + ','.join(builds) + '); runOnlyForDeploymentPostprocessing = 0;')
frameworks = obj('frameworks', f'isa = PBXFrameworksBuildPhase; buildActionMask = 2147483647; files = ({framework}); runOnlyForDeploymentPostprocessing = 0;')
resource_builds = []
for path,kind in [('App/Assets.xcassets','folder.assetcatalog'),('App/PrivacyInfo.xcprivacy','text.xml')]:
    ref=obj('resource:'+path,f'isa = PBXFileReference; lastKnownFileType = {kind}; path = {q(path)}; sourceTree = SOURCE_ROOT;')
    resource_builds.append(obj('resource-build:'+path,f'isa = PBXBuildFile; fileRef = {ref};'))
resources = obj('resources', 'isa = PBXResourcesBuildPhase; buildActionMask = 2147483647; files = ('+','.join(resource_builds)+'); runOnlyForDeploymentPostprocessing = 0;')
def config(name, release, target):
    settings = {'SWIFT_VERSION':'6.0', 'MACOSX_DEPLOYMENT_TARGET':'14.0', 'IPHONEOS_DEPLOYMENT_TARGET':'17.0', 'CLANG_ENABLE_MODULES':'YES', 'ONLY_ACTIVE_ARCH':'YES' if not release else 'NO', 'SWIFT_OPTIMIZATION_LEVEL':'-O' if release else '-Onone', 'SWIFT_ACTIVE_COMPILATION_CONDITIONS':'$(inherited)' if release else '$(inherited) DEBUG'}
    if target:
        settings.update({'PRODUCT_NAME':'FORGE', 'PRODUCT_BUNDLE_IDENTIFIER':'$(FORGE_APP_BUNDLE_ID)', 'SUPPORTED_PLATFORMS':'iphoneos iphonesimulator macosx', 'SDKROOT':'auto', 'TARGETED_DEVICE_FAMILY':'1,2', 'GENERATE_INFOPLIST_FILE':'YES', 'INFOPLIST_KEY_CFBundleDisplayName':'FORGE', 'INFOPLIST_KEY_LSApplicationCategoryType':'public.app-category.productivity', 'INFOPLIST_KEY_NSHumanReadableCopyright':'FORGE · Private personal software', 'INFOPLIST_KEY_NSCalendarsFullAccessUsageDescription':'Read today’s commitments to plan achievable work. FORGE never writes events automatically.', 'INFOPLIST_KEY_NSHealthShareUsageDescription':'Read steps, sleep and workout summaries to support your personal progress.', 'INFOPLIST_KEY_NSHealthUpdateUsageDescription':'FORGE does not write Health data.', 'INFOPLIST_KEY_UIApplicationSceneManifest_Generation':'YES', 'INFOPLIST_KEY_UILaunchScreen_Generation':'YES', 'INFOPLIST_KEY_ForgeCloudContainer':'$(FORGE_CLOUD_CONTAINER)', 'INFOPLIST_KEY_ForgeAppGroup':'$(FORGE_APP_GROUP)', 'SWIFT_ACTIVE_COMPILATION_CONDITIONS[sdk=iphone*]':'$(inherited) $(FORGE_IOS_FLAGS)', 'SWIFT_ACTIVE_COMPILATION_CONDITIONS[sdk=macosx*]':'$(inherited) $(FORGE_MAC_FLAGS)', 'ASSETCATALOG_COMPILER_APPICON_NAME':'AppIcon', 'CODE_SIGN_STYLE':'Automatic', 'CODE_SIGN_ENTITLEMENTS[sdk=macosx*]':'$(FORGE_MAC_ENTITLEMENTS)', 'CODE_SIGN_ENTITLEMENTS[sdk=iphone*]':'$(FORGE_IOS_ENTITLEMENTS)', 'ENABLE_HARDENED_RUNTIME':'YES', 'SWIFT_EMIT_LOC_STRINGS':'YES', 'CURRENT_PROJECT_VERSION':'1', 'MARKETING_VERSION':'1.0'})
    text = ' '.join(q(k) + ' = ' + q(v) + ';' for k,v in settings.items())
    return obj(name, f'isa = XCBuildConfiguration; baseConfigurationReference = {config_ref}; buildSettings = {{ {text} }}; name = {"Release" if release else "Debug"};')
pc = [config('project_debug',False,False), config('project_release',True,False)]
tc = [config('target_debug',False,True), config('target_release',True,True)]
pl = obj('project_configs', f'isa = XCConfigurationList; buildConfigurations = ({",".join(pc)}); defaultConfigurationIsVisible = 0; defaultConfigurationName = Release;')
tl = obj('target_configs', f'isa = XCConfigurationList; buildConfigurations = ({",".join(tc)}); defaultConfigurationIsVisible = 0; defaultConfigurationName = Release;')
extension_targets, extension_dependencies, extension_embeds = [], [], []
for name in ['Monitor','Report']:
    target_name='Forge'+name
    ext_ref=obj('ext-source:'+name,f'isa = PBXFileReference; lastKnownFileType = sourcecode.swift; path = Integrations/ScreenTime/{name}/{name}.swift; sourceTree = SOURCE_ROOT;')
    ext_build=obj('ext-build:'+name,f'isa = PBXBuildFile; fileRef = {ext_ref};')
    ext_phase=obj('ext-phase:'+name,f'isa = PBXSourcesBuildPhase; buildActionMask = 2147483647; files = ({ext_build}); runOnlyForDeploymentPostprocessing = 0;')
    ext_product=obj('ext-product:'+name,f'isa = PBXFileReference; explicitFileType = wrapper.app-extension; path = {target_name}.appex; sourceTree = BUILT_PRODUCTS_DIR;')
    ext_configs=[]
    for release in [False,True]:
        settings={'PRODUCT_NAME':target_name,'PRODUCT_BUNDLE_IDENTIFIER':f'$(FORGE_APP_BUNDLE_ID).{name.lower()}','SWIFT_VERSION':'6.0','IPHONEOS_DEPLOYMENT_TARGET':'17.0','SDKROOT':'iphoneos','SUPPORTED_PLATFORMS':'iphoneos iphonesimulator','TARGETED_DEVICE_FAMILY':'1,2','GENERATE_INFOPLIST_FILE':'YES','INFOPLIST_KEY_CFBundleDisplayName':target_name,'INFOPLIST_FILE':f'Integrations/ScreenTime/{name}/Info.plist','INFOPLIST_KEY_ForgeAppGroup':'$(FORGE_APP_GROUP)','CODE_SIGN_ENTITLEMENTS':'$(FORGE_EXTENSION_ENTITLEMENTS)' if name=='Monitor' else '$(FORGE_REPORT_ENTITLEMENTS)','APPLICATION_EXTENSION_API_ONLY':'YES','SKIP_INSTALL':'YES','CODE_SIGN_STYLE':'Automatic','CURRENT_PROJECT_VERSION':'1','MARKETING_VERSION':'1.0'}
        value=' '.join(q(k)+' = '+q(v)+';' for k,v in settings.items())
        ext_configs.append(obj('ext-config:'+name+str(release),f'isa = XCBuildConfiguration; baseConfigurationReference = {config_ref}; buildSettings = {{ {value} }}; name = {"Release" if release else "Debug"};'))
    ext_list=obj('ext-list:'+name,f'isa = XCConfigurationList; buildConfigurations = ({",".join(ext_configs)}); defaultConfigurationIsVisible = 0; defaultConfigurationName = Release;')
    ext_target=obj('ext-target:'+name,f'isa = PBXNativeTarget; buildConfigurationList = {ext_list}; buildPhases = ({ext_phase}); buildRules = (); dependencies = (); name = {target_name}; productName = {target_name}; productReference = {ext_product}; productType = "com.apple.product-type.app-extension";')
    extension_targets.append(ext_target)
    ext_proxy=obj('ext-proxy:'+name,f'isa = PBXContainerItemProxy; containerPortal = {ident("project")}; proxyType = 1; remoteGlobalIDString = {ext_target}; remoteInfo = {target_name};')
    extension_dependencies.append(obj('ext-dependency:'+name,f'isa = PBXTargetDependency; target = {ext_target}; targetProxy = {ext_proxy}; platformFilters = (ios);'))
    extension_embeds.append(obj('ext-embed:'+name,f'isa = PBXBuildFile; fileRef = {ext_product}; platformFilter = ios; settings = {{ ATTRIBUTES = (RemoveHeadersOnCopy); }};'))
embed=obj('embed', 'isa = PBXCopyFilesBuildPhase; buildActionMask = 2147483647; dstPath = ""; dstSubfolderSpec = 13; files = ('+','.join(extension_embeds)+'); name = "Embed App Extensions"; runOnlyForDeploymentPostprocessing = 0;')
target = obj('target', f'isa = PBXNativeTarget; buildConfigurationList = {tl}; buildPhases = ({sources},{frameworks},{resources},{embed}); buildRules = (); dependencies = ({",".join(extension_dependencies)}); name = FORGE; packageProductDependencies = ({core}); productName = FORGE; productReference = {product}; productType = "com.apple.product-type.application";')
ui_ref = obj('ui_ref', 'isa = PBXFileReference; lastKnownFileType = sourcecode.swift; path = UITests/ForgeUITests.swift; sourceTree = SOURCE_ROOT;')
ui_build = obj('ui_build', f'isa = PBXBuildFile; fileRef = {ui_ref};')
ui_sources = obj('ui_sources', f'isa = PBXSourcesBuildPhase; buildActionMask = 2147483647; files = ({ui_build}); runOnlyForDeploymentPostprocessing = 0;')
ui_product = obj('ui_product', 'isa = PBXFileReference; explicitFileType = wrapper.cfbundle; path = FORGEUITests.xctest; sourceTree = BUILT_PRODUCTS_DIR;')
ui_configs = []
for release in [False, True]:
    settings = {'PRODUCT_BUNDLE_IDENTIFIER':'$(FORGE_APP_BUNDLE_ID).UITests', 'SWIFT_VERSION':'6.0', 'IPHONEOS_DEPLOYMENT_TARGET':'17.0', 'GENERATE_INFOPLIST_FILE':'YES', 'CODE_SIGN_STYLE':'Automatic', 'SDKROOT':'auto', 'SUPPORTED_PLATFORMS':'iphoneos iphonesimulator macosx', 'MACOSX_DEPLOYMENT_TARGET':'14.0', 'TARGETED_DEVICE_FAMILY':'1,2', 'TEST_TARGET_NAME':'FORGE', 'PRODUCT_NAME':'$(TARGET_NAME)'}
    value = ' '.join(q(k)+' = '+q(v)+';' for k,v in settings.items())
    ui_configs.append(obj('ui_config_'+str(release), f'isa = XCBuildConfiguration; buildSettings = {{ {value} }}; name = {"Release" if release else "Debug"};'))
ui_list = obj('ui_config_list', f'isa = XCConfigurationList; buildConfigurations = ({",".join(ui_configs)}); defaultConfigurationIsVisible = 0; defaultConfigurationName = Release;')
proxy = obj('ui_proxy', f'isa = PBXContainerItemProxy; containerPortal = {ident("project")}; proxyType = 1; remoteGlobalIDString = {target}; remoteInfo = FORGE;')
dependency = obj('ui_dependency', f'isa = PBXTargetDependency; target = {target}; targetProxy = {proxy};')
ui_target = obj('ui_target', f'isa = PBXNativeTarget; buildConfigurationList = {ui_list}; buildPhases = ({ui_sources}); buildRules = (); dependencies = ({dependency}); name = FORGEUITests; productName = FORGEUITests; productReference = {ui_product}; productType = "com.apple.product-type.bundle.ui-testing";')
project = obj('project', f'isa = PBXProject; attributes = {{ BuildIndependentTargetsInParallel = YES; LastUpgradeCheck = 2700; }}; buildConfigurationList = {pl}; compatibilityVersion = "Xcode 14.0"; developmentRegion = en; knownRegions = (en,Base); mainGroup = {main}; productRefGroup = {products}; projectDirPath = ""; projectRoot = ""; packageReferences = ({package}); targets = ({target},{ui_target},{",".join(extension_targets)});')
emit(root / 'FORGE.xcodeproj/project.pbxproj', '// !$*UTF8*$!\n{ archiveVersion = 1; classes = {}; objectVersion = 56; objects = {\n' + '\n'.join(objects) + '\n}; rootObject = ' + project + '; }\n')
scheme = f'''<?xml version="1.0" encoding="UTF-8"?>
<Scheme LastUpgradeVersion="2700" version="1.3">
<BuildAction parallelizeBuildables="YES" buildImplicitDependencies="YES"><BuildActionEntries><BuildActionEntry buildForTesting="YES" buildForRunning="YES" buildForProfiling="YES" buildForArchiving="YES" buildForAnalyzing="YES"><BuildableReference BuildableIdentifier="primary" BlueprintIdentifier="{target}" BuildableName="FORGE.app" BlueprintName="FORGE" ReferencedContainer="container:FORGE.xcodeproj"/></BuildActionEntry></BuildActionEntries></BuildAction>
<TestAction buildConfiguration="Debug" selectedDebuggerIdentifier="Xcode.DebuggerFoundation.Debugger.LLDB" selectedLauncherIdentifier="Xcode.IDEFoundation.Launcher.LLDB" shouldUseLaunchSchemeArgsEnv="YES"><Testables><TestableReference skipped="NO"><BuildableReference BuildableIdentifier="primary" BlueprintIdentifier="{ui_target}" BuildableName="FORGEUITests.xctest" BlueprintName="FORGEUITests" ReferencedContainer="container:FORGE.xcodeproj"/></TestableReference></Testables></TestAction>
<LaunchAction buildConfiguration="Debug" selectedDebuggerIdentifier="Xcode.DebuggerFoundation.Debugger.LLDB" selectedLauncherIdentifier="Xcode.IDEFoundation.Launcher.LLDB" launchStyle="0" useCustomWorkingDirectory="NO" ignoresPersistentStateOnLaunch="NO" debugDocumentVersioning="YES" allowLocationSimulation="YES"><BuildableProductRunnable runnableDebuggingMode="0"><BuildableReference BuildableIdentifier="primary" BlueprintIdentifier="{target}" BuildableName="FORGE.app" BlueprintName="FORGE" ReferencedContainer="container:FORGE.xcodeproj"/></BuildableProductRunnable></LaunchAction>
<ProfileAction buildConfiguration="Release"/><AnalyzeAction buildConfiguration="Debug"/><ArchiveAction buildConfiguration="Release" revealArchiveInOrganizer="YES"/>
</Scheme>'''
emit(root / 'FORGE.xcodeproj/xcshareddata/xcschemes/FORGE.xcscheme', scheme)
print('Generated FORGE.xcodeproj')
