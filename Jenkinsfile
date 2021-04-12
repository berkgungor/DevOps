pipeline{
  agent any
  stages{
    stage('Build master') {
      when{
        branch 'master'
      }
      steps{
        echo 'Build master'
      }
    }
    stage('Build Dev'){
      when{
        branch'dev'
      }
      steps{
        echo 'Building dev'
      }
    }
  }
}
