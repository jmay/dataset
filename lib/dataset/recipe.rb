require "shellwords"

module Dataset
  def recipe_to_script(recipe)
    script = ""
    recipe.each do |stage|
      next if stage['command'].nil?
      script << stage['command']
      if stage['args']
        stage['args'].each_pair do |k,v|
          if v.is_a?(Array)
            v.each do |vv|
              script << " --#{k} '#{vv}'"
            end
          else
            script << " --#{k} '#{v}'"
          end
        end
      end
      script << "\n"
    end
    script
  end

  def script_to_recipe(script)
    recipe = []
    script.each_line do |line|
      words = Shellwords.shellwords(line.strip)
      next if words.empty?
      command = words.shift

      args = {}
      words.each_slice(2) do |k,v|
        k.gsub!(/^--/, '')
        if args[k]
          args[k] = [ args[k] ] unless args[k].is_a?(Array)
          args[k].push(v)
        else
          args[k] = v
        end
      end

      stage = {'command' => command}
      stage['args'] = args if args.any?
      recipe.push(stage)
    end
    recipe
  end

  module_function :recipe_to_script, :script_to_recipe
end
