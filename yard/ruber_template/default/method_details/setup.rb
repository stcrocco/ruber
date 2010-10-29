def init
  super
#   p self.class.ancestors
  idx = sections.index(:header) + 1
  sections.insert idx, :slot_signature
#   p sections
#   sections[idx].insert 1, :slot_signature
end

def slot_signature
  if object.parent[:slots] 
    sig = object.parent[:slots][object.name.to_s]
    if sig
      <<-HTML
      <h3 style="font-size: 1em; margin-bottom: 0;">Slot Signature:</h3>
      <p style="margin-top: 5pt;"><tt>#{object.name}#{sig}</tt></p>
      HTML
    end
  end
end