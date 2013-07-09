require_relative 'org_helper'
require_relative 'elasticsearch_id_generator'
require_relative 'query_builder'

class Deduplicator

  def initialize
    @idx = 'temp' # elasticsearch index & type name
    @server = Stretcher::Server.new('http://localhost:9200')
                  # Prepare an empty index
    @server.index(@idx).delete rescue nil
    @server.index(@idx).create()
    sleep 1
  end

  def dedupe(org)
    # TODO prepare query template & fill with data
    query = QueryBuilder.detect_duplicates_of org

    res = @server.index(@idx).search(size: 10, query: query)

    if (duplicate = is_duplicate(res))
      puts "Found duplicate: #{duplicate}"

      # merge duplicate with existing organization
      merged = OrgHelper.merge(org, duplicate)
      @server.index(@idx).type(@idx).put(merged['es_id'], merged)
      puts "Merged duplicates into an existing organization: #{merged}"
    else
      # save as a new organization:
      id = org['es_id'] = ElasticsearchIdGenerator.get_next
      @server.index(@idx).type(@idx).put(id, org)
      puts "Created new organization: #{org}"
    end
  end

  def is_duplicate(res)
    results = res.results.sort_by(&:_score)
    duplicates = results.select { |item| item._score > 1.5 }
    if duplicates.empty?
      nil
    else
      # take the one with the highest score, process it, return it
      duplicates.first.to_hash.select { |key, value| key.match(/^[^_]/) }
    end
  end
end