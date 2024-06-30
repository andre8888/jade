module ScrapeHelper
  USER_AGENT = 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/97.0.4692.99 Safari/537.36'

  def trim_text(text)
    text.gsub(/\D/,'').to_i
  rescue StandardError => e
    return nil
  end
end
