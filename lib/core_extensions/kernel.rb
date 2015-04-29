module CoreExtensions
  module Kernel
    module Browser
      def puts(*things)
        log = $document['log']
        log.inner_text = log.inner_text + "\n" + things * "\n"
      end
    end
  end
end

Kernel.include CoreExtensions::Kernel::Browser
