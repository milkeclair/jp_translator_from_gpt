# frozen_string_literal: true

require "fileutils"
require_relative "calculator"

module JpTranslatorFromGpt
  class Writer
    # ログをファイルに書き込む
    #
    # @param [Hash] response OpenAI APIからのレスポンス
    # @return [void]
    def self.write_logs(response)
      input_tokens = Translator.dig_used_tokens(response, "input")
      output_tokens = Translator.dig_used_tokens(response, "output")

      write_translated_text(response)
      write_used_tokens(input_tokens, output_tokens)
      write_total_cost(input_tokens, output_tokens)
    end

    # 出力先のテキストファイルのパスを返す
    # main.rbから見たパスで指定している
    #
    # @param [String] under_logs_path translator_logsディレクトリ配下のパス
    # @return [String] 出力先のテキストファイルのパス
    def self.text_path(under_logs_path)
      output_dir = "translator_logs"
      FileUtils.mkdir_p(output_dir) unless File.directory?(output_dir)
      File.join("translator_logs", under_logs_path)
    end

    # 翻訳されたテキストをファイルに書き込み、ターミナルに出力する
    # テキストはファイルの末尾に追記される
    #
    # @param [Hash] response OpenAI APIからのレスポンス
    # @return [void]
    def self.write_translated_text(response)
      log_file_path = text_path("translated_text.txt")
      File.open(log_file_path, "a") do |file|
        translated_text = response["choices"][0]["message"]["content"]
        file.puts(translated_text)
      end
    end

    # 使用したトークン数をファイルに書き込む
    # ファイルのテキストは上書きされる
    #
    # @param [Integer] input_tokens 入力トークン数
    # @param [Integer] output_tokens 出力トークン数
    # @return [void]
    def self.write_used_tokens(input_tokens, output_tokens)
      log_file_path = text_path("tokens.txt")
      existing_input_tokens, existing_output_tokens = read_existing_tokens(log_file_path)

      total_input_tokens = existing_input_tokens + input_tokens
      total_output_tokens = existing_output_tokens + output_tokens

      File.open(log_file_path, "w") do |file|
        file.puts("input: #{total_input_tokens}")
        file.puts("output: #{total_output_tokens}")
      end
    end

    # ファイルにあるトークン数を読み込む
    #
    # @param [String] log_file_path トークン数が書かれたファイルのパス
    # @return [Array<Integer>] 入力トークン数と出力トークン数
    def self.read_existing_tokens(log_file_path)
      existing_input_tokens, existing_output_tokens = 0, 0

      if File.exist?(log_file_path)
        File.readlines(log_file_path).each do |line|
          existing_input_tokens = line.split(":").last.strip.to_i if line.start_with?("input:")
          existing_output_tokens = line.split(":").last.strip.to_i if line.start_with?("output:")
        end
      end

      [existing_input_tokens, existing_output_tokens]
    end

    # トークン数から利用料金を計算し、ファイルにある合計金額に加算して書き込む
    # ファイルのテキストは上書きされる
    #
    # @param [Integer] input_tokens 入力トークン数
    # @param [Integer] output_tokens 出力トークン数
    # @return [void]
    def self.write_total_cost(input_tokens, output_tokens)
      log_file_path = text_path("cost.txt")
      this_cost =
        Calculator.calc_total_cost(input_tokens, "input") + Calculator.calc_total_cost(output_tokens, "output")
      existing_cost =
        if File.exist?(log_file_path)
          File.read(log_file_path).gsub("$", "").to_f
        else
          0.0
        end
      total_cost = this_cost + existing_cost

      File.open(log_file_path, "w") do |file|
        # 小数点以下8桁まで表示
        file.puts("$#{format("%.8f", total_cost)}")
      end
    end
  end
end
