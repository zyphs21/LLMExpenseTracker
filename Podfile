#source 'https://github.com/CocoaPods/Specs.git' #官方索引库
source 'https://cdn.cocoapods.org/' #官方索引库

platform :ios, '16.0'
inhibit_all_warnings!

def share_pods
  pod 'SnapKit'
  pod 'RxCocoa'
  pod 'RxSwift'
  pod 'Moya'
  pod 'Moya/RxSwift'
end

target 'LLMExpenseTracker' do
    use_frameworks!
    share_pods
end
