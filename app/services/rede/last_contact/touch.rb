# Ponto de chamada do "último contato" (decisão 5 da spec 005). Não faz nada até a spec 006 implementar.
class Rede::LastContact::Touch
  def initialize(interaction:)
    @interaction = interaction
  end

  def perform; end
end
