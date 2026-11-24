#!/usr/bin/env python3
"""Deterministic Xcode project generator. No XcodeGen or package dependencies."""
import hashlib
import json
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
objects = {}
def uid(key):
    return hashlib.sha1(key.encode()).hexdigest()[:24].upper()
def obj(key, isa, **fields):
    ident = uid(key)
    objects[ident] = dict(isa=isa, **fields)
    return ident
def ref(key, path, kind, **kwargs):
    return obj(key, 'PBXFileReference', lastKnownFileType=kind, path=path, sourceTree='<group>', **kwargs)
def build(key, file):
    return obj(key, 'PBXBuildFile', fileRef=file)

app_sources = sorted(ROOT.glob('Painter/**/*.swift'))
test_sources = sorted(ROOT.glob('PainterTests/*.swift'))
ui_sources = sorted(ROOT.glob('PainterUITests/*.swift'))
resources = sorted(ROOT.glob('Painter/Resources/*.mp4')) + sorted(ROOT.glob('Painter/Resources/Fonts/*.ttf')) + [ROOT/'Painter/Resources/PrivacyInfo.xcprivacy', ROOT/'Painter/Resources/Assets.xcassets']
all_refs = []
source_builds = {}
for target, files in [('Painter', app_sources), ('PainterTests', test_sources), ('PainterUITests', ui_sources)]:
    source_builds[target] = []
    for file in files:
        path = file.relative_to(ROOT).as_posix()
        file_ref = ref(path, path, 'sourcecode.swift')
        all_refs.append(file_ref)
        source_builds[target].append(build('build:'+path, file_ref))
resource_builds = []
for file in resources:
    path = file.relative_to(ROOT).as_posix()
    kind = {'.mp4':'video.mp4', '.ttf':'file', '.xcprivacy':'text.xml', '.xcassets':'folder.assetcatalog'}[file.suffix]
    file_ref = ref(path, path, kind)
    all_refs.append(file_ref)
    resource_builds.append(build('build:'+path, file_ref))
all_refs.append(ref('info', 'Painter/Info.plist', 'text.plist.xml'))
all_refs.append(ref('storekit', 'Painter/Resources/TraceStudio.storekit', 'text'))
products = []
for target in ['Painter', 'PainterTests', 'PainterUITests']:
    products.append(obj('product:'+target,'PBXFileReference',explicitFileType='wrapper.application' if target=='Painter' else 'wrapper.cfbundle', path=target+('.app' if target=='Painter' else '.xctest'), sourceTree='BUILT_PRODUCTS_DIR'))
product_group = obj('products','PBXGroup',children=products,name='Products',sourceTree='<group>')
main_group = obj('main','PBXGroup',children=all_refs+[product_group],sourceTree='<group>')
targets=[]
for target,product in zip(['Painter','PainterTests','PainterUITests'],products):
    sources = obj('sources:'+target,'PBXSourcesBuildPhase',buildActionMask=2147483647,files=source_builds[target],runOnlyForDeploymentPostprocessing=0)
    frameworks = obj('frameworks:'+target,'PBXFrameworksBuildPhase',buildActionMask=2147483647,files=[],runOnlyForDeploymentPostprocessing=0)
    res = obj('resources:'+target,'PBXResourcesBuildPhase',buildActionMask=2147483647,files=resource_builds if target=='Painter' else [],runOnlyForDeploymentPostprocessing=0)
    configs=[]
    for config in ['Debug','Release']:
        settings={'PRODUCT_NAME':'$(TARGET_NAME)','PRODUCT_BUNDLE_IDENTIFIER':'com.karamba555.painter'+('' if target=='Painter' else '.'+target.lower()),'SWIFT_VERSION':'5.0','IPHONEOS_DEPLOYMENT_TARGET':'17.0','TARGETED_DEVICE_FAMILY':'1,2','CODE_SIGN_STYLE':'Automatic','CURRENT_PROJECT_VERSION':'1','MARKETING_VERSION':'0.1.0','LD_RUNPATH_SEARCH_PATHS':['$(inherited)','@executable_path/Frameworks'],'GENERATE_INFOPLIST_FILE':'YES' if target!='Painter' else 'NO'}
        if target=='Painter':
            settings.update(INFOPLIST_FILE='Painter/Info.plist',ENABLE_PREVIEWS='YES',SUPPORTS_MACCATALYST='NO',TRACE_API_BASE_URL='')
        elif target=='PainterTests':
            settings.update(TEST_HOST='$(BUILT_PRODUCTS_DIR)/Painter.app/$(BUNDLE_EXECUTABLE_FOLDER_PATH)/Painter',BUNDLE_LOADER='$(TEST_HOST)')
        else:
            settings.update(TEST_TARGET_NAME='Painter')
        configs.append(obj('config:'+target+config,'XCBuildConfiguration',buildSettings=settings,name=config))
    config_list=obj('configs:'+target,'XCConfigurationList',buildConfigurations=configs,defaultConfigurationIsVisible=0,defaultConfigurationName='Release')
    deps=[]
    if target!='Painter':
        proxy=obj('proxy:'+target,'PBXContainerItemProxy',containerPortal=uid('project'),proxyType=1,remoteGlobalIDString=uid('target:Painter'),remoteInfo='Painter')
        deps=[obj('dep:'+target,'PBXTargetDependency',target=uid('target:Painter'),targetProxy=proxy)]
    targets.append(obj('target:'+target,'PBXNativeTarget',buildConfigurationList=config_list,buildPhases=[sources,frameworks,res],buildRules=[],dependencies=deps,name=target,productName=target,productReference=product,productType='com.apple.product-type.application' if target=='Painter' else 'com.apple.product-type.bundle.unit-test' if target=='PainterTests' else 'com.apple.product-type.bundle.ui-testing'))
configs=[]
for config in ['Debug','Release']:
    settings={'ALWAYS_SEARCH_USER_PATHS':'NO','CLANG_ENABLE_MODULES':'YES','CLANG_ENABLE_OBJC_ARC':'YES','SDKROOT':'iphoneos','IPHONEOS_DEPLOYMENT_TARGET':'17.0','SWIFT_VERSION':'5.0','ENABLE_TESTABILITY':'YES' if config=='Debug' else 'NO','SWIFT_OPTIMIZATION_LEVEL':'-Onone' if config=='Debug' else '-O','GCC_OPTIMIZATION_LEVEL':'0' if config=='Debug' else 's','SWIFT_ACTIVE_COMPILATION_CONDITIONS':'DEBUG $(inherited)' if config=='Debug' else '$(inherited)','DEBUG_INFORMATION_FORMAT':'dwarf' if config=='Debug' else 'dwarf-with-dsym','ONLY_ACTIVE_ARCH':'YES' if config=='Debug' else 'NO'}
    configs.append(obj('projectconfig:'+config,'XCBuildConfiguration',buildSettings=settings,name=config))
project_configs=obj('projectconfigs','XCConfigurationList',buildConfigurations=configs,defaultConfigurationIsVisible=0,defaultConfigurationName='Release')
obj('project','PBXProject',attributes={'BuildIndependentTargetsInParallel':'YES','LastUpgradeCheck':'1600','TargetAttributes':{uid('target:'+t):{'CreatedOnToolsVersion':'16.0'} for t in ['Painter','PainterTests','PainterUITests']}},buildConfigurationList=project_configs,compatibilityVersion='Xcode 14.0',developmentRegion='en',hasScannedForEncodings=0,knownRegions=['en','Base'],mainGroup=main_group,productRefGroup=product_group,projectDirPath='',projectRoot='',targets=targets)

def encode(value, level=0):
    if isinstance(value,dict):
        return '{\n'+''.join('\t'*(level+1)+json.dumps(str(k))+' = '+encode(v,level+1)+';\n' for k,v in value.items())+'\t'*level+'}'
    if isinstance(value,list):return '('+', '.join(encode(v,level) for v in value)+')'
    if isinstance(value,int):return str(value)
    return json.dumps(value)

project=ROOT/'Painter.xcodeproj';project.mkdir(exist_ok=True)
(project/'project.pbxproj').write_text('// !$*UTF8*$!\n'+encode({'archiveVersion':1,'classes':{},'objectVersion':56,'objects':objects,'rootObject':uid('project')})+'\n')
scheme_dir=project/'xcshareddata/xcschemes';scheme_dir.mkdir(parents=True,exist_ok=True)
def buildable(target):
    return f'<BuildableReference BuildableIdentifier="primary" BlueprintIdentifier="{uid("target:"+target)}" BuildableName="{target}{".app" if target=="Painter" else ".xctest"}" BlueprintName="{target}" ReferencedContainer="container:Painter.xcodeproj"/>'
(scheme_dir/'Painter.xcscheme').write_text(f'''<?xml version="1.0" encoding="UTF-8"?>
<Scheme LastUpgradeVersion="1600" version="1.3">
<BuildAction parallelizeBuildables="YES" buildImplicitDependencies="YES"><BuildActionEntries>
<BuildActionEntry buildForTesting="YES" buildForRunning="YES" buildForProfiling="YES" buildForArchiving="YES" buildForAnalyzing="YES">{buildable('Painter')}</BuildActionEntry>
</BuildActionEntries></BuildAction>
<TestAction buildConfiguration="Debug" selectedDebuggerIdentifier="Xcode.DebuggerFoundation.Debugger.LLDB" selectedLauncherIdentifier="Xcode.IDEFoundation.Launcher.LLDB" shouldUseLaunchSchemeArgsEnv="YES"><Testables>
<TestableReference skipped="NO">{buildable('PainterTests')}</TestableReference>
<TestableReference skipped="NO">{buildable('PainterUITests')}</TestableReference>
</Testables></TestAction>
<LaunchAction buildConfiguration="Debug" selectedDebuggerIdentifier="Xcode.DebuggerFoundation.Debugger.LLDB" selectedLauncherIdentifier="Xcode.IDEFoundation.Launcher.LLDB" launchStyle="0" useCustomWorkingDirectory="NO" ignoresPersistentStateOnLaunch="NO" debugDocumentVersioning="YES" debugServiceExtension="internal" allowLocationSimulation="YES"><BuildableProductRunnable runnableDebuggingMode="0">{buildable('Painter')}</BuildableProductRunnable></LaunchAction>
<ProfileAction buildConfiguration="Release" shouldUseLaunchSchemeArgsEnv="YES" savedToolIdentifier="" useCustomWorkingDirectory="NO" debugDocumentVersioning="YES"><BuildableProductRunnable runnableDebuggingMode="0">{buildable('Painter')}</BuildableProductRunnable></ProfileAction>
<AnalyzeAction buildConfiguration="Debug"/><ArchiveAction buildConfiguration="Release" revealArchiveInOrganizer="YES"/>
</Scheme>''')
print(f'Generated project: {len(app_sources)} app sources, {len(resources)} resources')
