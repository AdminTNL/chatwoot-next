module AutoAssignmentHandler
  extend ActiveSupport::Concern
  include Events::Types

  included do
    after_save :run_auto_assignment
  end

  private

  # Auto-atribuição desligada (spec 040): o sistema não atribui conversa a pessoa.
  # Este método será removido, junto com o restante do código de auto-atribuição, na etapa 2.
  def run_auto_assignment
    nil
  end
end
