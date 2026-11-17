class Rede::Projects::Builder
  def self.for_team(team, ensure_roles: true)
    new(team, ensure_roles: ensure_roles).perform
  end

  def initialize(team, ensure_roles: true)
    @team = team
    @account = team.account
    @ensure_roles = ensure_roles
  end

  def perform
    name = @team.name.titleize
    Rede::Roles::EnsureDefaults.new(@account).perform if @ensure_roles
    Rede::Project.create!(account: @account, team: @team, name: name, slug: unique_slug(name), color: color)
  end

  private

  def unique_slug(name)
    base = name.parameterize.presence || 'projeto'
    taken = @account.rede_projects.where('slug = :base OR slug LIKE :prefix', base: base, prefix: "#{base}-%").pluck(:slug)
    return base unless taken.include?(base)

    suffix = 2
    suffix += 1 while taken.include?("#{base}-#{suffix}")
    "#{base}-#{suffix}"
  end

  def color
    return @team.icon_color if @team.icon_color.to_s.match?(Rede::Project::COLOR_FORMAT)

    Rede::Project::COLOR_PALETTE[@account.rede_projects.count % Rede::Project::COLOR_PALETTE.size]
  end
end
