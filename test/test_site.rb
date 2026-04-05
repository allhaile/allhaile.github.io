# encoding: utf-8
require "minitest/autorun"
require "date"
require "yaml"
require "rexml/document"
require "nokogiri"

SITE_DIR  = File.expand_path("../../_site", __FILE__)
ROOT_DIR  = File.expand_path("../..", __FILE__)
POSTS_DIR = File.join(ROOT_DIR, "_posts")

def read_utf8(path)
  File.read(path, encoding: "UTF-8")
end

# ─── Build verification ───

class TestSiteBuilds < Minitest::Test
  def test_site_directory_exists
    assert Dir.exist?(SITE_DIR), "_site directory should exist after build"
  end

  def test_index_html_generated
    assert File.exist?(File.join(SITE_DIR, "index.html")), "index.html should be generated"
  end

  def test_blog_index_generated
    assert File.exist?(File.join(SITE_DIR, "blog", "index.html")), "blog/index.html should be generated"
  end

  def test_feed_xml_generated
    assert File.exist?(File.join(SITE_DIR, "feed.xml")), "feed.xml should be generated"
  end

  def test_css_generated
    assert File.exist?(File.join(SITE_DIR, "assets", "css", "main.css")), "main.css should be generated"
  end
end

# ─── Jekyll config ───

class TestJekyllConfig < Minitest::Test
  def setup
    @config = YAML.load_file(File.join(ROOT_DIR, "_config.yml"))
  end

  def test_title_is_haile_api
    assert_equal "Haile API", @config["title"]
  end

  def test_url_is_github_pages
    assert_equal "https://allhaile.github.io", @config["url"]
  end

  def test_plugins_include_feed
    assert_includes @config["plugins"], "jekyll-feed"
  end

  def test_plugins_include_seo
    assert_includes @config["plugins"], "jekyll-seo-tag"
  end

  def test_author_is_configured
    assert @config["author"], "author should be configured"
    assert_equal "Haile Shavers", @config["author"]["name"]
  end

  def test_permalink_format
    assert @config["permalink"], "permalink should be configured"
    assert_match %r{/blog/}, @config["permalink"]
  end
end

# ─── Blog posts source ───

class TestBlogPostSource < Minitest::Test
  def setup
    @posts = Dir.glob(File.join(POSTS_DIR, "*.md"))
  end

  def test_at_least_one_post_exists
    refute_empty @posts, "should have at least one blog post"
  end

  def test_posts_have_valid_filenames
    @posts.each do |post|
      basename = File.basename(post)
      assert_match(/\d{4}-\d{2}-\d{2}-.+\.md/, basename,
        "Post #{basename} should follow YYYY-MM-DD-title.md format")
    end
  end

  def test_posts_have_required_front_matter
    @posts.each do |post|
      content = read_utf8(post)
      assert_match(/\A---\n/, content, "#{File.basename(post)} should start with front matter")

      front_matter = YAML.safe_load(content.split("---")[1], permitted_classes: [Date, Time])
      assert front_matter["title"], "#{File.basename(post)} needs a title"
      assert front_matter["date"],  "#{File.basename(post)} needs a date"
      assert front_matter["layout"], "#{File.basename(post)} needs a layout"
    end
  end

  def test_posts_have_body_content
    @posts.each do |post|
      parts = read_utf8(post).split("---", 3)
      body = parts[2].to_s.strip
      refute_empty body, "#{File.basename(post)} should have body content"
    end
  end
end

# ─── Homepage HTML ───

class TestHomepage < Minitest::Test
  def setup
    @doc = Nokogiri::HTML(read_utf8(File.join(SITE_DIR, "index.html")))
  end

  def test_has_haile_api_branding
    nav_text = @doc.css(".nav-logo").text
    assert_match(/haile.*api/i, nav_text, "Nav should contain Haile API branding")
  end

  def test_has_hero_section
    hero = @doc.css(".hero")
    refute_empty hero, "Homepage should have a hero section"
  end

  def test_hero_mentions_haile
    hero_text = @doc.css(".hero h1").text
    assert_match(/haile/i, hero_text, "Hero heading should mention Haile")
  end

  def test_has_endpoint_cards
    cards = @doc.css(".endpoint-card")
    assert cards.length >= 3, "Should have at least 3 endpoint cards, got #{cards.length}"
  end

  def test_has_experience_section
    exp = @doc.css(".experience")
    refute_empty exp, "Homepage should have an experience section"
  end

  def test_has_projects_section
    projects = @doc.css(".projects")
    refute_empty projects, "Homepage should have a projects section"
  end

  def test_has_nav_links
    links = @doc.css(".nav-link")
    link_texts = links.map(&:text).map(&:strip)
    assert_includes link_texts, "home"
    assert_includes link_texts, "blog"
    assert_includes link_texts, "rss"
  end

  def test_has_footer
    footer = @doc.css(".footer")
    refute_empty footer, "Homepage should have a footer"
  end

  def test_has_rss_autodiscovery
    rss_link = @doc.css('link[type="application/rss+xml"]')
    refute_empty rss_link, "Should have RSS autodiscovery link in <head>"
  end

  def test_project_images_reference_existing_files
    @doc.css(".project-card img").each do |img|
      src = img["src"]
      path = File.join(SITE_DIR, src)
      assert File.exist?(path), "Project image should exist: #{src}"
    end
  end
end

# ─── Blog index HTML ───

class TestBlogIndex < Minitest::Test
  def setup
    @doc = Nokogiri::HTML(read_utf8(File.join(SITE_DIR, "blog", "index.html")))
  end

  def test_has_blog_header
    header = @doc.css(".blog-header h1")
    refute_empty header, "Blog page should have a header"
    assert_equal "Blog", header.text.strip
  end

  def test_lists_posts
    items = @doc.css(".blog-item")
    assert items.length >= 1, "Blog index should list at least 1 post"
  end

  def test_post_links_are_valid
    @doc.css(".blog-item a").each do |link|
      href = link["href"]
      assert_match %r{^/blog/\d{4}/\d{2}/\d{2}/}, href, "Post link should match permalink pattern: #{href}"
    end
  end
end

# ─── Blog post HTML ───

class TestBlogPost < Minitest::Test
  def setup
    posts = Dir.glob(File.join(SITE_DIR, "blog", "**", "index.html"))
      .reject { |p| p == File.join(SITE_DIR, "blog", "index.html") }
    skip("No rendered posts found") if posts.empty?
    @doc = Nokogiri::HTML(read_utf8(posts.first))
  end

  def test_has_post_title
    title = @doc.css(".post-title")
    refute_empty title, "Blog post should have a title"
  end

  def test_has_post_date
    date = @doc.css(".post-meta time")
    refute_empty date, "Blog post should have a date"
    assert date.first["datetime"], "Date should have datetime attribute"
  end

  def test_has_post_content
    content = @doc.css(".post-content")
    refute_empty content, "Blog post should have content"
    assert content.text.strip.length > 50, "Post content should have substantial text"
  end

  def test_has_back_link
    back = @doc.css(".back-link")
    refute_empty back, "Blog post should have a back link to blog index"
  end

  def test_has_nav_and_footer
    refute_empty @doc.css(".nav"), "Blog post should have nav"
    refute_empty @doc.css(".footer"), "Blog post should have footer"
  end
end

# ─── RSS Feed ───

class TestRSSFeed < Minitest::Test
  def setup
    @feed_path = File.join(SITE_DIR, "feed.xml")
    @content = read_utf8(@feed_path)
    @doc = REXML::Document.new(@content)
  end

  def test_is_valid_xml
    assert @doc.root, "feed.xml should be valid XML"
  end

  def test_has_rss_root_element
    assert_equal "rss", @doc.root.name, "Root element should be <rss>"
    assert_equal "2.0", @doc.root.attributes["version"], "RSS version should be 2.0"
  end

  def test_has_channel
    channel = @doc.root.elements["channel"]
    assert channel, "Feed should have a <channel>"
  end

  def test_channel_has_title
    title = @doc.root.elements["channel/title"]
    assert title, "Channel should have a <title>"
    assert_equal "Haile API", title.text
  end

  def test_channel_has_link
    link = @doc.root.elements["channel/link"]
    assert link, "Channel should have a <link>"
    assert_match %r{allhaile\.github\.io}, link.text
  end

  def test_has_items
    items = @doc.root.get_elements("channel/item")
    assert items.length >= 1, "Feed should have at least 1 item"
  end

  def test_items_have_required_fields
    @doc.root.get_elements("channel/item").each do |item|
      assert item.elements["title"],   "Item should have <title>"
      assert item.elements["link"],    "Item should have <link>"
      assert item.elements["pubDate"], "Item should have <pubDate>"
      assert item.elements["guid"],    "Item should have <guid>"
    end
  end
end

# ─── Layouts & Includes source ───

class TestLayoutsExist < Minitest::Test
  def test_default_layout_exists
    assert File.exist?(File.join(ROOT_DIR, "_layouts", "default.html"))
  end

  def test_post_layout_exists
    assert File.exist?(File.join(ROOT_DIR, "_layouts", "post.html"))
  end

  def test_head_include_exists
    assert File.exist?(File.join(ROOT_DIR, "_includes", "head.html"))
  end

  def test_nav_include_exists
    assert File.exist?(File.join(ROOT_DIR, "_includes", "nav.html"))
  end

  def test_footer_include_exists
    assert File.exist?(File.join(ROOT_DIR, "_includes", "footer.html"))
  end
end
