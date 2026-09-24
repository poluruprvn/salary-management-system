module Api
  module V1
    class LevelsController < BaseController
      def index
        render json: { data: Level.order(:rank).map { |level| LevelSerializer.new(level) } }
      end
    end
  end
end
