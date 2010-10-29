# include T('method_details')
# include Template

def init
  super
#   p self.class.ancestors
#   @sections = YARD::Templates::Section.new nil
  sections :signal_header, [:signal_signature, T('docstring')]
#   p self.class.ancestors
end