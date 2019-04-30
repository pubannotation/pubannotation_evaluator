# PubAnnotation Evaluator
It is an evaluation tool for annotations in PubAnnotation JSON format.
It compares a set of annotations under evaluation (we call it _study annotations_) against another set of annotations which we assume trustible (_reference annotations_), and reports the difference in precision, recall, and f-score.
It also shows false positives and false negatives.

# Requirement
Please use it with ruby version 2.3 or above.
If your system does not already have an installation of ruby, you need to install it. Using [rvm](https://rvm.io/) is generally a recommended way to install ruby in your system.

# Install
It is released as a gemfile, which is a standard package distribution system of the ruby programming language.
Please use the following ruby command to install it:
```console
> gem install pubannotation_evaluator
```

# Execuete
This package includes an excutable command, _pubannotation-eval_. Executing it without any argument will show you how to use it.
```console
> pubannotation-eval
Usage: pubannotation-eval.rb [options] annotation_file(s)
    -r, --rdir=DIR                   specifies the path to the directory of reference annotation_file(s).
    -c, --soft-match-characters=INT  specifies the number of characters to allow for boundary mismatch (default=20).
    -w, --soft-match-words=INT       specifies the number of words to allow for boundary mismatch (default=2).
    -D, --denotation-type-match=TEXT specifies a ruby block to determine type match of two denotations (defalut='study_type == reference_type ? 1 : 0').
    -R, --relation-type-match=TEXT   specifies a ruby block to determine type match of two denotations (defalut='study_type == reference_type ? 1 : 0').
    -v, --verbose                    tells it to report false positives and false negatives.
    -h, --help                       displays this screen.
```
Suppose you have your study annotations in the directory, _sdir_, and your reference annotations in _rdir_, the simplest way to evaluate your study annotations is as follows:
```console
> pubannotation-eval -r rdir sdir/*.json
```

### Soft boundary matching
It is generally believed that requiring strict boundary matching for entity recognition does not make much sense, and evaluation with relaxed boudnary matching is practically much more useful. You can control the softness factor through two optional parameters, _c_ and _w_.
For example, the following command compares annotations on the basis of strict boudnary matching.
```console
> pubannotation-eval -r rdir -c 0 -w 0 sdir/*.json
```
By default, c = 20 and w = 2, which means boundary mismatch by 2 words (within 20 characters) will be considered fine.

### Custom matching
By default, the type of denotations and relations are compared strictly. However, you can control it yourself by supplying a ruby block for it.
For example, below is the default ruby block for exact label matching:
```ruby
study_type == reference_type ? 1 : 0
```
It means if the type of a study annotation is the same as the type of a reference annotation, it will return 1. Otherwise, it will return 0.

For a little bit complex example, the following block will allow mismatch between 'gene' and 'protein':
```ruby
if study_type == reference_type
    1
elsif (study_type == 'gene' && reference_type == 'protein') || (study_type == 'protein' && reference_type == 'gene')
    1
else
    0
end
```
Or, you can even give different the scores for different matching:
```ruby
if study_type == reference_type
    1
elsif (study_type == 'gene' && reference_type == 'protein') || (study_type == 'protein' && reference_type == 'gene')
    0.5
else
    0
end
```
Then, the result will what we call weighted precision / recall / f-score.

## Output
It reports
* count of annotations
* precision/recall/fscore
* list of false positives and false negatives

## Author
Jin-Dong Kim (jdkim@dbcls.rois.ac.jp)

## License
Released under the [MIT license](http://opensource.org/licenses/MIT).
