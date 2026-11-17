# Ponto único de normalização de telefone do módulo Rede (reusado pela 011).
module Rede::Phone
  E164_FORMAT = /\A\+[1-9]\d{1,14}\z/
  BRAZIL_DDI = '55'.freeze

  # Devolve o telefone em E.164 ou nil se não der para interpretar.
  # Com "+", respeita o DDI informado. Sem "+": 12 ou 13 dígitos começando em 55 já trazem o DDI;
  # 10 ou 11 dígitos (DDD + número) assumem +55. Qualquer outra coisa é inválida.
  def self.normalize(raw)
    text = raw.to_s.strip
    digits = text.gsub(/\D/, '')
    return nil if digits.empty?

    e164 = text.start_with?('+') ? "+#{digits}" : with_default_country(digits)
    e164 if e164&.match?(E164_FORMAT)
  end

  # O número informado primeiro e, para celular brasileiro, a forma com ou sem o nono dígito.
  def self.variants(e164)
    return [e164] unless e164.to_s.start_with?("+#{BRAZIL_DDI}")

    ddd = e164[3, 2]
    local = e164[5..].to_s
    if local.length == 9 && local.start_with?('9')
      [e164, "+#{BRAZIL_DDI}#{ddd}#{local[1..]}"]
    elsif local.length == 8 && local.match?(/\A[6-9]/)
      [e164, "+#{BRAZIL_DDI}#{ddd}9#{local}"]
    else
      [e164]
    end
  end

  def self.with_default_country(raw_digits)
    digits = raw_digits.sub(/\A0+/, '')
    return "+#{digits}" if digits.start_with?(BRAZIL_DDI) && [12, 13].include?(digits.length)
    return "+#{BRAZIL_DDI}#{digits}" if [10, 11].include?(digits.length)

    nil
  end
  private_class_method :with_default_country
end
