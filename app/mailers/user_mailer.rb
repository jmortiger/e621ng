# frozen_string_literal: true

class UserMailer < ActionMailer::Base
  helper ApplicationHelper
  helper UsersHelper
  default from: Danbooru.config.mail_from_addr, content_type: "text/html"

  def dmail_notice(dmail)
    @dmail = dmail
    mail(to: "#{dmail.to.name} <#{dmail.to.email}>", subject: "#{Danbooru.config.app_name} - Message received from #{dmail.from.name}")
  end

  def self.create_notice_body(user, forum_topic, forum_posts)
    # render(template: "user_mailer/forum_notice", assigns: { user: user, forum_topic: forum_topic, forum_posts: forum_posts }, format: "html")
    # render_to_string(inline: "\"<%= @forum_topic.title %>\" was updated:\n\n<% @forum_posts.each do |forum_post| %>\n  [section=<%= forum_post.creator_name %> said:]\n    <%= forum_post.body %>\n  [/section]\n<% end %>\n\n<%= link_to 'View topic', forum_topic_url(@forum_topic, :page => @forum_topic.last_page, :host => Danbooru.config.hostname, :only_path => false) %> | <%= link_to 'Unsubscribe', maintenance_user_email_notification_url(:user_id => @user.id, :sig => email_sig(@user, :unsubscribe), :host => Danbooru.config.hostname, :only_path => false) %>", assigns: { user: user, forum_topic: forum_topic, forum_posts: forum_posts })
    # "\"#{forum_topic.title}\" was updated:\n\n#{forum_posts.inject('') do |acc, forum_post|
    #   "#{acc}\n  [section=#{forum_post.creator_name} said:]\n    #{forum_post.body}\n  [/section]\n"
    # end}\n\n#{link_to 'View topic', forum_topic_url(forum_topic, page: forum_topic.last_page, host: Danbooru.config.hostname, only_path: false)} | #{link_to 'Unsubscribe', maintenance_user_email_notification_url(user_id: user.id, sig: email_sig(user, :unsubscribe), host: Danbooru.config.hostname, only_path: false)}"
    # "\"#{forum_topic.title}\" was updated:\n\n#{forum_posts.inject('') do |acc, forum_post|
    #   "#{acc}\n  [section=#{forum_post.creator_name} said:]\n    #{forum_post.body}\n  [/section]\n"
    # end}\n\n\"View topic\":[#{forum_topic_url(forum_topic, page: forum_topic.last_page, host: Danbooru.config.hostname, only_path: false)} | \"Unsubscribe\"#{maintenance_user_email_notification_url(user_id: user.id, sig: email_sig(user, :unsubscribe), host: Danbooru.config.hostname, only_path: false)}"
    "\"#{forum_topic.title}\" was updated:\n\n#{forum_posts.inject('') do |acc, forum_post|
      "#{acc}\n  [section=#{forum_post.creator_name} said:]\n    #{forum_post.body}\n  [/section]\n"
    end}\n\n\"View topic\":[#{Danbooru.config.hostname}/forum_topics/#{forum_topic.id}?page=#{forum_topic.last_page}]"
=begin
    "\"#{forum_topic.title} %>\" was updated:

<% @forum_posts.each do |forum_post| %>
  [section=<%= forum_post.creator_name %> said:]
    <%= forum_post.body %>
  [/section]
<% end %>

<%= link_to 'View topic', forum_topic_url(@forum_topic, :page => @forum_topic.last_page, :host => Danbooru.config.hostname, :only_path => false) %> | <%= link_to 'Unsubscribe', maintenance_user_email_notification_url(:user_id => @user.id, :sig => email_sig(@user, :unsubscribe), :host => Danbooru.config.hostname, :only_path => false) %>"
=end
  end

  def forum_notice(user, forum_topic, forum_posts)
    # TODO: Add setting to disable getting dmails for the forums
    @user = user
    @forum_topic = forum_topic
    @forum_posts = forum_posts
    body = UserMailer.create_notice_body(user, forum_topic, forum_posts)
    # puts "Body: #{body}"
    # TODO: Add setting to disable getting dmails for the forums
    Dmail.create_automated(
      to_id: user.id,
      title: "Forum topic #{forum_topic.title} updated",
      body: body,
    )
    mail(to: "#{user.name} <#{user.email}>", subject: "#{Danbooru.config.app_name} forum topic #{forum_topic.title} updated")
  end
end
