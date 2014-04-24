# coding: utf-8
Gem::Specification.new do |spec|
  spec.name          = 'git-bump'
  spec.version       = '1.0.0'
  spec.authors       = ['Tim Pope']
  spec.email         = ["code\100tpope.net"]
  spec.description   = 'Git based release management'
  spec.summary       = 'Create Git release commits and tags with changelogs'
  spec.homepage      = 'https://tpo.pe/git-bump'
  spec.license       = 'MIT'

  spec.files         = ['bin/git-bump', 'lib/git_bump.rb']
  spec.executables   = ['git-bump']
  spec.require_paths = ['lib']

  spec.add_development_dependency 'bundler', '~> 1.3'
  spec.add_development_dependency 'rake'
  spec.add_dependency 'thor'
end
