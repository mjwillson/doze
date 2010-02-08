module Doze::Serialization::FormDataHelpers

  private

  def escape(s)
    s.to_s.gsub(/([^ a-zA-Z0-9_.-]+)/n) {
      '%'+$1.unpack('H2'*$1.size).join('%').upcase
    }.tr(' ', '+')
  end

  def unescape(s)
    s.tr('+', ' ').gsub(/((?:%[0-9a-fA-F]{2})+)/n){
      [$1.delete('%')].pack('H*')
    }
  end

  def normalize_params(parms, name, val=nil)
    name =~ %r([\[\]]*([^\[\]]+)\]*)
    key = $1 || ''
    after = $' || ''

    if after == ""
      parms[key] = val
    elsif after == "[]"
      (parms[key] ||= []) << val
    elsif after =~ %r(^\[\]\[([^\[\]]+)\]$)
      child_key = $1
      parms[key] ||= []
      if parms[key].last.is_a?(Hash) && !parms[key].last.key?(child_key)
        parms[key].last.update(child_key => val)
      else
        parms[key] << { child_key => val }
      end
    else
      parms[key] ||= {}
      parms[key] = normalize_params(parms[key], after, val)
    end
    parms
  end
end
