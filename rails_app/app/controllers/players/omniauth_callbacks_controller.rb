class Players::OmniauthCallbacksController < Devise::OmniauthCallbacksController
  def facebook
    callback_from :facebook
  end

  private

  def callback_from(provider)
    provider = provider.to_s

    auth = request.env['omniauth.auth']
    @player = Player.find_for_oauth(auth)

    if @player.present?
      @player.update!(access_token: auth['credentials']['token'])
    else
      @player = Player.create!(provider: auth['provider'], uid: auth['uid'], access_token: auth['credentials']['token'])
    end

    flash[:notice] = I18n.t('devise.omniauth_callbacks.success', kind: provider.capitalize)
    sign_in_and_redirect @player, event: :authentication
  end
end
