Gem::Specification.new do |s|
  s.name        = 'pubannotation_evaluator'
  s.version     = '1.0.0'
  s.summary     = 'It compares a set of annotations (study annotations) against another set of annotations (reference annotations), and evaluates the accuracy of the study annotations.'
  s.date        = Time.now.utc.strftime("%Y-%m-%d")
  s.description = 'A tool to evaluate the accuracy of a set of annotations.'
  s.authors     = ["Jin-Dong Kim"]
  s.email       = 'jdkim@dbcls.rois.ac.jp'
  s.files       = ["lib/pubannotation_evaluator.rb", "lib/pubannotation_evaluator/pubannotation_evaluator.rb"]
  s.executables = ["pubannotation-eval"]
  s.homepage    = 'https://github.com/pubannotation/pubannotation_evaluator'
  s.license     = 'MIT'
end