module Kernel
  def puts(*things)
    log = $document['log']
    log.inner_text = log.inner_text + "\n" + things * "\n"
  end
end

class String
  def classify
    Object.const_get self
  end

  def camelize
    scan(/[a-zA-Z0-9]+/).map(&:capitalize).join
  end
end
