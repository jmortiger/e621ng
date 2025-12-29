# frozen_string_literal: true

class UserStatus < ApplicationRecord
  belongs_to :user

  def self.for_user(user_id)
    where("user_statuses.user_id = ?", user_id)
  end

  module CountMethods
    def self.post(user_id)
      Post.for_user(user_id).count
    end

    def self.post_deleted(user_id)
      # puts "Post.for_user(user_id): #{Post.for_user(user_id).count} #{Post.for_user(user_id)}"
      # puts "Post.not_taken_down: #{Post.not_taken_down.count} #{Post.not_taken_down}"
      Post.for_user(user_id).deleted.not_taken_down.count # Post.for_user(user_id).deleted.count
    end

    def self.post_update(user_id)
      PostVersion.for_user(user_id).count
    end

    def self.favorite(user_id)
      Favorite.for_user(user_id).count
    end

    def self.note(user_id)
      NoteVersion.for_user(user_id).count
    end

    def self.own_post_replaced(user_id)
      PostReplacement.for_uploader_on_approve(user_id).count
    end

    def self.own_post_replaced_penalize(user_id)
      PostReplacement.penalized.for_uploader_on_approve(user_id).count
    end

    # TODO: Summary
    # ### Parameters
    # * `user` {`Integer` | `User`}
    # ### Returns
    # TODO: Returns
    def self.post_replacement_rejected(user)
      user.is_a?(User) ? user.post_replacements.rejected.count : PostReplacement.for_creator(user).rejected.count
    end
  end
end
