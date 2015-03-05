=begin rdoc
Helper module to resolve the conflict between +Enumerable#count+ and the +count+
methods a lot of Qt/KDE classes provide.

It is essentially like +Enumerable+, but defines a <tt>count_items</tt> method
rather than a +count+ method. Qt/KDE classes can then mix-in this module instead
of +Enumerable+. The same effect could have been obtained by modifying +Enumerable+,
but that could have interferred with other libraries
=end
module QtEnumerable

  include Enumerable

  begin
    alias_method :count_items, :count
    undef_method :count
  rescue NoMethodError
  end

end
