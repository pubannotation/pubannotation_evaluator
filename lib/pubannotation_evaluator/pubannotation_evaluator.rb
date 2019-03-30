class PubannotationEvaluator
	BOUNDARY_SOFTNESS_CHARACTER = 20
	BOUNDARY_SOFTNESS_WORD = 2

	def initialize(boundary_softness_character = BOUNDARY_SOFTNESS_CHARACTER, boundary_softness_word = BOUNDARY_SOFTNESS_WORD)
		@boundary_softness_character = boundary_softness_character
		@boundary_softness_word = boundary_softness_word
	end

	# To compare two sets of annotations
	#
	# ===== Attributes
	#
	# * +study_annotations+ : annotations to be studied
	# * +reference_annotations+ : annotations to be compared against
	def compare(study_annotations, reference_annotations)
		study_annotations[:denotations] ||= []
		study_annotations[:relations] ||= []
		study_annotations[:modifications] ||= []
		reference_annotations[:denotations] ||= []
		reference_annotations[:relations] ||= []
		reference_annotations[:modifications] ||= []

		comparison_denotations, mmatches_denotations = compare_denotations(study_annotations[:denotations], reference_annotations[:denotations], reference_annotations[:text])
		comparison_relations = compare_relations(study_annotations[:relations], reference_annotations[:relations], mmatches_denotations)
		comparison_modifications = compare_modifications(study_annotations[:modofications], reference_annotations[:modofications], comparison_denotations, comparison_relations)

		comparison = comparison_denotations.collect{|a| a.merge(type: :denotation)} +
								 comparison_relations.collect{|a| a.merge(type: :relation)} +
								 comparison_modifications.collect{|a| a.merge(type: :modification)}

		docspec = {sourcedb:study_annotations[:sourcedb], sourceid:study_annotations[:sourceid]}
		docspec[:divid] = study_annotations[:divid] if study_annotations.has_key?(:divid)
		comparison.collect{|d| d.merge(docspec)}
	end

	# To produce evaluations based on comparison.
	#
	# ===== Attributes
	#
	# * +comparison+ : the mapping between study and reference annotations
	def evaluate(comparison)
		counts = count(comparison)
		measures = measure(counts)
		{counts:counts, measures:measures}
	end

	private

	def compare_denotations(study_denotations, reference_denotations, text)
		mmatches = find_denotation_mmatches(study_denotations, reference_denotations, text)
		matches  = find_denotation_matches(mmatches)
		false_positives = study_denotations - matches.collect{|r| r[:study]}
		false_negatives = reference_denotations - matches.collect{|r| r[:reference]}
		comparison = matches + false_positives.collect{|s| {study:s}} + false_negatives.collect{|r| {reference:r}}
		[comparison, mmatches]
	end

	# To find every possible matches based on the denotation match criteria
	def find_denotation_mmatches(study_denotations, reference_denotations, text)
		study_denotations = study_denotations.sort_by{|d| [d[:span][:begin], -d[:span][:end]]}
		reference_denotations = reference_denotations.sort_by{|d| [d[:span][:begin], -d[:span][:end]]}

		matches = []
		study_denotations.each do |s|
			r_begin = reference_denotations.bsearch_index{|r| r[:span][:end] > s[:span][:begin]}
			r_end = reference_denotations.bsearch_index{|r| r[:span][:begin] > s[:span][:end]}
			r_end = r_end.nil? ? -1 : r_end - 1
			reference_denotations[r_begin .. r_end].each do |r|
				relatedness = get_relatedness_of_denotations(s, r, text)
				matches << {study:s, reference:r, weight:relatedness} if relatedness > 0
			end
		end

		matches
	end

	# To determine how much the two annotations match to each other based on the denotation match criteria
	def get_relatedness_of_denotations(s, r, text)
		# at least there should be an overlap
		return 0 if s[:span][:end] <= r[:span][:begin] || s[:span][:begin] >= r[:span][:end]

		# character-level tolerance
		return 0 if (s[:span][:begin] - r[:span][:begin]).abs > @boundary_softness_character || (s[:span][:end] - r[:span][:end]).abs > @boundary_softness_character

		# word-level tolerance
		front_mismatch = if s[:span][:begin] < r[:span][:begin]
			text[s[:span][:begin] ... r[:span][:begin]]
		else
			text[r[:span][:begin] ... s[:span][:begin]]
		end
		return 0 if front_mismatch.count(' ') > @boundary_softness_word

		rear_mismatch = if s[:span][:end] < r[:span][:end]
			text[s[:span][:end] ... r[:span][:end]]
		else
			text[r[:span][:end] ... s[:span][:end]]
		end
		return 0 if rear_mismatch.count(' ') > @boundary_softness_word

		return s[:obj] == r[:obj] ? 1 : 0.5
	end

	def find_denotation_matches(matches)
		comp = Proc.new do |a, b|
			c = a[:weight] <=> b[:weight]
			if c.zero?
				c = (b[:study][:span][:end] - b[:reference][:span][:end]).abs <=> (a[:study][:span][:end] - a[:reference][:span][:end]).abs
				if c.zero?
					c = (b[:study][:span][:begin] - b[:reference][:span][:begin]).abs <=> (a[:study][:span][:begin] - a[:reference][:span][:begin]).abs
				else
					c
				end
			else
				c
			end
		end
		find_exclusive_matches(matches, comp)
	end

	def compare_relations(study_relations, reference_relations, mmatch_denotations)
		matches = find_relation_matches(find_relation_mmatches(study_relations, reference_relations, mmatch_denotations))
		false_positives = study_relations - matches.collect{|r| r[:study]}
		false_negatives = reference_relations - matches.collect{|r| r[:reference]}
		matches + false_positives.collect{|s| {study:s}} + false_negatives.collect{|r| {reference:r}}
	end

	def find_relation_mmatches(study_relations, reference_relations, mmatch_denotations)
		matches = []
		study_relations.each do |s|
			reference_relations.each do |r|
				relatedness = get_relatedness_of_relations(s, r, mmatch_denotations)
				matches << {study:s, reference:r, weight:relatedness} if relatedness > 0
			end
		end
		matches
	end

	def get_relatedness_of_relations(s, r, mmatch_denotations)
		# at least, the subject and object of the two relateions should match to each other.
		match_subj = mmatch_denotations.find{|m| m[:study] && m[:reference] && m[:study][:id] == s[:subj] && m[:reference][:id] == r[:subj]}
		return 0 if match_subj.nil?

		match_obj = mmatch_denotations.find{|m| m[:study] && m[:reference] && m[:study][:id] == s[:obj] && m[:reference][:id] == r[:obj]}
		return 0 if match_obj.nil?

		# predicate match
		match_pred_weight = s[:pred] == r[:pred] ? 1 : 0

		return (match_subj[:weight] + match_obj[:weight] + match_pred_weight).to_f / 3
	end

	def find_relation_matches(matches)
		comp = Proc.new do |a, b|
			a[:weight] <=> b[:weight]
		end

		find_exclusive_matches(matches, comp)
	end


	def compare_modifications(study_modifications, reference_modifications, comparison_relations, compare_relations)
		[]
	end

	# To find the best exclusive matches.
	# It is an implementation of a greey algorithm.
	def find_exclusive_matches(matches, comp)
		return [] if matches.empty?

		# find exclusive matches for study annotations
		s_matched = []
		r_matched = []
		matches_group_by_s = matches.group_by{|m| m[:study]}
		matches_group_by_s.each_value do |m|
			if m.length == 1
				s_matched << m[0][:study]
				r_matched << m[0][:reference]
			else
				m.delete_if{|i| r_matched.include?(i[:reference])}
				m_sel = m.max{|a, b| comp.call(a, b)}
				m.replace([m_sel])
				s_matched << m_sel[:study]
				r_matched << m_sel[:reference]
			end
		end
		matches = matches_group_by_s.values.reduce(:+)

		# find exclusive matches for reference annotations
		matches_group_by_r = matches.group_by{|m| m[:reference]}
		matches_group_by_r.each_value do |m|
			if m.length > 1
				max = m.max{|a, b| comp.call(a, b)}
				m.replace([max])
			end
		end
		matches_group_by_r.values.reduce(:+)
	end

	def count(comparison)
		# counts of denotations
		count_study_denotations = begin
			count = Hash.new(0)
			study_denotations = comparison.select{|m| m[:study] && m[:type]==:denotation}
			study_denotations.group_by{|m| m[:study][:obj]}.each{|k, m| count[k] = m.count}
			count.update('All' => study_denotations.count)
		end

		count_reference_denotations = begin
			count = Hash.new(0)
			reference_denotations = comparison.select{|m| m[:reference] && m[:type]==:denotation}
			reference_denotations.group_by{|m| m[:reference][:obj]}.each{|k, m| count[k] = m.count}
			count.update('All' => reference_denotations.count)
		end

		count_study_match_denotations = begin
			count = Hash.new(0)
			study_match_denotations = comparison.select{|m| m[:study] && m[:reference] && m[:type]==:denotation}
			study_match_denotations.group_by{|m| m[:study][:obj]}.each{|k, m| count[k] = m.count}
			count.update('All' => study_match_denotations.count)
		end

		count_reference_match_denotations = begin
			count = Hash.new(0)
			reference_match_denotations = comparison.select{|m| m[:study] && m[:reference] && m[:type]==:denotation}
			reference_match_denotations.group_by{|m| m[:reference][:obj]}.each{|k, m| count[k] = m.count}
			count.update('All' => reference_match_denotations.count)
		end

		counts = {
			denotations: {
				study: count_study_denotations,
				reference: count_reference_denotations,
				matched_study: count_study_match_denotations,
				matched_reference: count_reference_match_denotations
			}
		}

		return counts if comparison.index{|m| m[:type]==:relation}.nil?

		# counts of relations
		count_study_relations = begin
			count = Hash.new(0)
			study_relations = comparison.select{|m| m[:study] && m[:type]==:relation}
			study_relations.group_by{|m| m[:study][:pred]}.each{|k, m| count[k] = m.count}
			count.update('All' => study_relations.count)
		end

		count_reference_relations = begin
			count = Hash.new(0)
			reference_relations = comparison.select{|m| m[:reference] && m[:type]==:relation}
			reference_relations.group_by{|m| m[:reference][:pred]}.each{|k, m| count[k] = m.count}
			count.update('All' => reference_relations.count)
		end

		count_study_match_relations = begin
			count = Hash.new(0)
			study_match_relations = comparison.select{|m| m[:study] && m[:reference] && m[:type]==:relation}
			study_match_relations.group_by{|m| m[:study][:pred]}.each{|k, m| count[k] = m.count}
			count.update('All' => study_match_relations.count)
		end

		count_reference_match_relations = begin
			count = Hash.new(0)
			reference_match_relations = comparison.select{|m| m[:study] && m[:reference] && m[:type]==:relation}
			reference_match_relations.group_by{|m| m[:reference][:pred]}.each{|k, m| count[k] = m.count}
			count.update('All' => reference_match_relations.count)
		end

		counts.update(
			relations: {
				study: count_study_relations,
				reference: count_reference_relations,
				matched_study: count_study_match_relations,
				matched_reference: count_reference_match_relations,
			}
		)
	end

	def measure(counts)
		# prf: precision / recall / fscore
		measures = {denotations: get_prf(counts[:denotations])}
		return measures if counts[:relations].nil?
		measures.update(relations: get_prf(counts[:relations]))
	end

	def get_prf(counts)
		keys = (counts[:study].keys + counts[:reference].keys).uniq
		precision = keys.inject(Hash.new(0)){|m, k| m[k] = counts[:study][k] > 0 ? counts[:matched_study][k].to_f / counts[:study][k] : 0; m}
		recall = keys.inject(Hash.new(0)){|m, k| m[k] = counts[:reference][k] > 0 ? counts[:matched_reference][k].to_f / counts[:reference][k] : 0; m}
		fscore = keys.inject(Hash.new(0)){|m, k| p = precision[k]; r = recall[k]; m[k] = (p * r) > 0 ? 2.to_f * p * r / (p + r) : 0; m}
		{
			precision: precision,
			recall: recall,
			fscore: fscore
		}
	end

end

# execution code for debugging
if __FILE__ == $0
	require 'json'
	raise ArgumentError, "call me with two filenames, one for the study annotations, and the other for reference annotations." unless ARGV.length == 2
	s = JSON.parse File.read(ARGV[0]), :symbolize_names => true
	r = JSON.parse File.read(ARGV[1]), :symbolize_names => true
  comparer = PubAnnotationComparer.new
  comparison = comparer.compare(s, r)
  pp comparison
end
