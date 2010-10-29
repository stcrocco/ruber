def init
  super
  sections.place(T('api')).before(:children)
end