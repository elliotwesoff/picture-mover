class UserInput

  attr_accessor :last_ans

  def initialize
  end

  def get_input(name = nil)
    ans = gets
    ans.downcase!
    ans.chomp!
    ans.strip!
    # handle backslashes properly for windows and linux paths.
    ans[0...2].match(/[A-Z]:/i) ? ans.gsub!(/\\/, "/") : ans.gsub!(/\\/, "")
    @last_ans = ans
    record_answer(name, ans) if name
    return ans
  end

  def truthy_answer(ans)
    return false unless ans
    ans = ans.downcase
    case ans
    when 'yes', 'y', 'yep', 'yeah', 'ja', 'si', 'oui'
      true
    else
      false
    end
  end

  private
  
  def record_answer(name, ans)
    var = if name.to_s.include? "@"
      name.to_s
    else
      "@#{name.to_s}"
    end

    instance_variable_set(var, ans)
  end

end