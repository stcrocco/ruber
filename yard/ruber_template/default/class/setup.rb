def init
  super
  sections.place(:signal_summary).before(:constructor_details)
  sections.place(:signal_details).after(:method_details_list)
  sections[:signal_details] << T('signal')
  sections.delete T('api')
  sections.place(T('api')).after(:signal_summary)
end