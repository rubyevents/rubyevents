require "test_helper"

class TransliterateTest < ActiveSupport::TestCase
  test "keeps the German and Cyrillic approximations" do
    assert_equal "achim-krueger", "Achim Krüger".parameterize
    assert_equal "bjoern-rochel", "Björn Rochel".parameterize
    assert_equal "ivan-petrov", "Иван Петров".parameterize
  end

  test "keeps the default approximations" do
    assert_equal "jose-valim", "José Valim".parameterize
    assert_equal "lukasz-zolw", "Łukasz Żółw".parameterize
  end

  test "removes the accents from letters missing from the approximations" do
    assert_equal "hieu-nguyen", "Hiếu Nguyễn".parameterize
    assert_equal "gheorghita-hurmuz", "Gheorghiță Hurmuz".parameterize
  end

  test "removes combining accents" do
    assert_equal "jose-valim", "José Valim".parameterize
  end

  test "spells out compatibility characters" do
    assert_equal "i3-systems-inc", "i³ Systems, Inc.".parameterize
    assert_equal "finance", "ﬁnance".parameterize
  end

  test "drops characters without a Latin approximation" do
    assert_equal "ann", "蒼時弦也 Ann".parameterize
  end
end
