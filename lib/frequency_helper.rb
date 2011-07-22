module FrequencyHelper
  def code_from_frequency(frequency)
    return 'A' if frequency == :year || frequency == "year" || frequency == :annual || frequency == "annual"
    return 'Q' if frequency == :quarter || frequency == "quarter"
    return 'M' if frequency == :month || frequency == "month"
    return ""
  end
  
  def frequency_from_code(code)
    return :year if code == 'A' || code =="a"
    return :quarter if code == 'Q' || code =="q"
    return :month if code == 'M' || code == "m"
    return nil
  end
end